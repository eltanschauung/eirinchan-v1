defmodule Eirinchan.Posts do
  @moduledoc """
  Minimal posting pipeline for OP and reply creation.
  """

  import Ecto.Query, only: [from: 2]

  alias Eirinchan.Build
  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Posts.Post
  alias Eirinchan.Repo
  alias Eirinchan.Runtime.Config
  alias Eirinchan.ThreadPaths
  alias Eirinchan.Uploads

  @spec create_post(BoardRecord.t(), map(), keyword()) ::
          {:ok, Post.t(), map()}
          | {:error,
             :thread_not_found
             | :invalid_post_mode
             | :invalid_referer
             | :board_locked
             | :thread_locked
             | :body_required
             | :reply_hard_limit
             | :image_hard_limit
             | :invalid_image
             | :image_too_large
             | :duplicate_file
             | :file_required
             | :invalid_file_type
             | :file_too_large
             | :upload_failed}
          | {:error, Ecto.Changeset.t()}
  def create_post(%BoardRecord{} = board, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    config = Keyword.get(opts, :config, Config.compose())
    request = Keyword.get(opts, :request, %{})
    attrs = normalize_attrs(attrs)

    with {:ok, attrs} <- prepare_upload(attrs, config) do
      thread_param = blank_to_nil(Map.get(attrs, "thread"))
      op? = is_nil(thread_param)
      attrs = normalize_post_identity(attrs, config)
      noko = noko?(attrs["email"], config)
      attrs = normalize_noko_email(attrs)
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      with :ok <- validate_post_button(op?, attrs, config),
           :ok <- validate_referer(request, config),
           :ok <- validate_board_lock(config),
           {:ok, thread} <- fetch_thread(board, thread_param, repo),
           :ok <- validate_thread_lock(thread),
           :ok <- validate_body(op?, attrs, config),
           :ok <- validate_upload(op?, attrs, config),
           :ok <- validate_image_dimensions(attrs, config),
           :ok <- validate_reply_limit(board, thread, config, repo),
           :ok <- validate_image_limit(board, thread, attrs, config, repo),
           :ok <- validate_duplicate_upload(board, thread, attrs, config, repo),
           {:ok, post} <- create_post_record(board, thread, attrs, repo, config, now) do
        _ = Build.rebuild_after_post(board, post, config: config, repo: repo)
        {:ok, post, %{noko: noko}}
      end
    end
  end

  @spec update_thread_state(BoardRecord.t(), String.t() | integer(), map(), keyword()) ::
          {:ok, Post.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_thread_state(%BoardRecord{} = board, thread_id, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    config = Keyword.get(opts, :config, Config.compose())

    with {:ok, [thread | _]} <- get_thread(board, thread_id, repo: repo),
         {:ok, updated_thread} <-
           thread
           |> Post.thread_state_changeset(attrs)
           |> repo.update() do
      _ = Build.rebuild_thread_state(board, updated_thread.id, config: config, repo: repo)
      {:ok, updated_thread}
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end

  @spec delete_post(BoardRecord.t(), String.t() | integer(), String.t() | nil, keyword()) ::
          {:ok, map()} | {:error, :post_not_found | :invalid_password | Ecto.Changeset.t()}
  def delete_post(%BoardRecord{} = board, post_id, password, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    config = Keyword.get(opts, :config, Config.compose())
    password = trim_to_nil(password)

    with {:ok, normalized_post_id} <- normalize_thread_id(post_id),
         %Post{} = post <- repo.get_by(Post, id: normalized_post_id, board_id: board.id),
         :ok <- validate_delete_password(post, password),
         file_paths <- post_delete_file_paths(post, repo),
         {:ok, _deleted_post} <- repo.delete(post) do
      Enum.each(file_paths, &Uploads.remove/1)

      result =
        if is_nil(post.thread_id) do
          _ = Build.rebuild_after_delete(board, {:thread, post}, config: config, repo: repo)
          %{deleted_post_id: post.id, thread_id: post.id, thread_deleted: true}
        else
          _ =
            Build.rebuild_after_delete(board, {:reply, post.thread_id}, config: config, repo: repo)

          %{deleted_post_id: post.id, thread_id: post.thread_id, thread_deleted: false}
        end

      {:ok, result}
    else
      :error -> {:error, :post_not_found}
      nil -> {:error, :post_not_found}
      {:error, :invalid_password} -> {:error, :invalid_password}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end

  @spec list_threads(BoardRecord.t(), keyword()) :: [Post.t()]
  def list_threads(%BoardRecord{} = board, opts \\ []) do
    config = Keyword.get(opts, :config, Config.compose())
    page = Keyword.get(opts, :page, 1)
    {:ok, page_data} = list_threads_page(board, page, Keyword.put(opts, :config, config))
    Enum.map(page_data.threads, & &1.thread)
  end

  @spec list_page_data(BoardRecord.t(), keyword()) :: {:ok, [map()]} | {:error, :not_found}
  def list_page_data(%BoardRecord{} = board, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    config = Keyword.get(opts, :config, Config.compose())

    with {:ok, first_page} <- list_threads_page(board, 1, config: config, repo: repo) do
      page_data =
        Enum.map(1..first_page.total_pages, fn page ->
          {:ok, data} = list_threads_page(board, page, config: config, repo: repo)
          data
        end)

      {:ok, page_data}
    end
  end

  @spec list_threads_page(BoardRecord.t(), pos_integer(), keyword()) ::
          {:ok, map()} | {:error, :not_found}
  def list_threads_page(%BoardRecord{} = board, page, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    config = Keyword.get(opts, :config, Config.compose())
    threads_per_page = config.threads_per_page
    max_pages = config.max_pages

    total_threads =
      repo.aggregate(
        from(post in Post, where: post.board_id == ^board.id and is_nil(post.thread_id)),
        :count,
        :id
      )

    total_pages =
      total_threads
      |> Kernel./(threads_per_page)
      |> Float.ceil()
      |> trunc()
      |> max(1)
      |> min(max_pages)

    if page < 1 or page > total_pages do
      {:error, :not_found}
    else
      offset = (page - 1) * threads_per_page

      threads =
        repo.all(
          from post in Post,
            where: post.board_id == ^board.id and is_nil(post.thread_id),
            order_by: [desc: post.sticky, desc_nulls_last: post.bump_at, desc: post.inserted_at],
            limit: ^threads_per_page,
            offset: ^offset
        )

      summaries = Enum.map(threads, &thread_summary(board, &1, config, repo))
      pages = build_pages(board, total_pages, config)

      {:ok,
       %{
         board: board,
         threads: summaries,
         page: page,
         total_pages: total_pages,
         pages: pages
       }}
    end
  end

  @spec get_thread(BoardRecord.t(), String.t() | integer(), keyword()) ::
          {:ok, [Post.t()]} | {:error, :not_found}
  def get_thread(%BoardRecord{} = board, thread_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    with {:ok, normalized_thread_id} <- normalize_thread_id(thread_id),
         %Post{} = thread <-
           repo.one(
             from post in Post,
               where:
                 post.id == ^normalized_thread_id and post.board_id == ^board.id and
                   is_nil(post.thread_id)
           ) do
      replies =
        repo.all(
          from post in Post,
            where: post.board_id == ^board.id and post.thread_id == ^thread.id,
            order_by: [asc: post.inserted_at, asc: post.id]
        )

      {:ok, [thread | replies]}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec find_thread_page(BoardRecord.t(), String.t() | integer(), keyword()) ::
          {:ok, pos_integer()} | {:error, :not_found}
  def find_thread_page(%BoardRecord{} = board, thread_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    config = Keyword.get(opts, :config, Config.compose())

    with {:ok, normalized_thread_id} <- normalize_thread_id(thread_id) do
      visible_thread_ids =
        repo.all(
          from post in Post,
            where: post.board_id == ^board.id and is_nil(post.thread_id),
            order_by: [desc: post.sticky, desc_nulls_last: post.bump_at, desc: post.inserted_at],
            limit: ^(config.threads_per_page * config.max_pages),
            select: post.id
        )

      case Enum.find_index(visible_thread_ids, &(&1 == normalized_thread_id)) do
        nil -> {:error, :not_found}
        index -> {:ok, div(index, config.threads_per_page) + 1}
      end
    else
      :error -> {:error, :not_found}
    end
  end

  @spec get_thread_view(BoardRecord.t(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, :not_found}
  def get_thread_view(%BoardRecord{} = board, thread_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    with {:ok, [thread | replies]} <- get_thread(board, thread_id, repo: repo) do
      reply_image_count = Enum.count(replies, &image_post?/1)

      {:ok,
       %{
         thread: thread,
         replies: replies,
         reply_count: length(replies),
         image_count: reply_image_count + image_count(thread),
         omitted_posts: 0,
         omitted_images: 0,
         last_modified: thread.bump_at || thread.inserted_at
       }}
    end
  end

  defp create_post_record(board, thread, attrs, repo, config, now) do
    upload = Map.get(attrs, "file")
    upload_metadata = Map.get(attrs, "__upload_metadata__")

    case repo.transaction(fn ->
           with {:ok, post} <- insert_post(board, thread, attrs, repo, config, now),
                {:ok, post} <-
                  maybe_store_upload(board, post, upload, upload_metadata, repo, config) do
             maybe_bump_thread(thread, attrs, config, repo, now)
             maybe_cycle_thread(board, thread, config, repo)
             post
           else
             {:error, reason} -> repo.rollback(reason)
           end
         end) do
      {:ok, post} -> {:ok, post}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_store_upload(_board, %Post{} = post, nil, _metadata, _repo, _config), do: {:ok, post}

  defp maybe_store_upload(board, %Post{} = post, %Plug.Upload{} = upload, metadata, repo, config) do
    case Uploads.store(board, post, upload, config, metadata) do
      {:ok, metadata} ->
        case post |> Post.create_changeset(metadata) |> repo.update() do
          {:ok, updated_post} ->
            {:ok, updated_post}

          {:error, %Ecto.Changeset{} = changeset} ->
            Uploads.remove(metadata.file_path)
            Uploads.remove(metadata.thumb_path)
            {:error, changeset}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp insert_post(board, nil, attrs, repo, config, now) do
    attrs =
      attrs
      |> Map.put("board_id", board.id)
      |> Map.put("thread_id", nil)
      |> Map.put("bump_at", now)
      |> Map.put("sticky", false)
      |> Map.put("locked", false)
      |> Map.put("cycle", false)
      |> Map.put("sage", false)
      |> Map.put("slug", maybe_slugify(attrs, config))

    %Post{}
    |> Post.create_changeset(attrs)
    |> repo.insert()
  end

  defp insert_post(board, thread, attrs, repo, _config, _now) do
    attrs =
      attrs
      |> Map.put("board_id", board.id)
      |> Map.put("thread_id", thread.id)

    %Post{}
    |> Post.create_changeset(attrs)
    |> repo.insert()
  end

  defp normalize_attrs(attrs) do
    attrs
    |> Enum.into(%{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      pair -> pair
    end)
  end

  defp prepare_upload(attrs, config) do
    case Map.get(attrs, "file") do
      %Plug.Upload{} = upload ->
        case Uploads.describe(upload, config) do
          {:ok, metadata} -> {:ok, Map.put(attrs, "__upload_metadata__", metadata)}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:ok, attrs}
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp normalize_post_identity(attrs, config) do
    attrs
    |> Map.update("name", config.anonymous, &default_name(&1, config))
    |> Map.update("subject", nil, &trim_to_nil/1)
    |> Map.update("password", nil, &trim_to_nil/1)
    |> Map.update("email", nil, &normalize_email/1)
  end

  defp default_name(nil, config), do: config.anonymous

  defp default_name(value, config) do
    case trim_to_nil(value) do
      nil -> config.anonymous
      trimmed -> trimmed
    end
  end

  defp trim_to_nil(nil), do: nil

  defp trim_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(value),
    do: value |> String.trim() |> String.replace(" ", "%20") |> blank_to_nil()

  defp normalize_noko_email(attrs) do
    case String.downcase(attrs["email"] || "") do
      "noko" -> Map.put(attrs, "email", nil)
      "nonoko" -> Map.put(attrs, "email", nil)
      _ -> attrs
    end
  end

  defp noko?(email, config) do
    case String.downcase(email || "") do
      "noko" -> true
      "nonoko" -> false
      _ -> config.always_noko
    end
  end

  defp validate_post_button(true, attrs, config) do
    if attrs["post"] == config.button_newtopic, do: :ok, else: {:error, :invalid_post_mode}
  end

  defp validate_post_button(false, attrs, config) do
    if attrs["post"] == config.button_reply, do: :ok, else: {:error, :invalid_post_mode}
  end

  defp validate_referer(_request, %{referer_match: false}), do: :ok

  defp validate_referer(request, config) do
    referer = request[:referer] || request["referer"]

    if is_binary(referer) and Regex.match?(config.referer_match, URI.decode(referer)) do
      :ok
    else
      {:error, :invalid_referer}
    end
  end

  defp validate_board_lock(config) do
    if config.board_locked, do: {:error, :board_locked}, else: :ok
  end

  defp validate_thread_lock(nil), do: :ok
  defp validate_thread_lock(%Post{locked: true}), do: {:error, :thread_locked}
  defp validate_thread_lock(%Post{}), do: :ok

  defp fetch_thread(_board, nil, _repo), do: {:ok, nil}

  defp fetch_thread(board, thread_param, repo) do
    with {:ok, thread_id} <- normalize_thread_id(thread_param),
         %Post{} = thread <-
           repo.one(
             from post in Post,
               where:
                 post.id == ^thread_id and post.board_id == ^board.id and is_nil(post.thread_id)
           ) do
      {:ok, thread}
    else
      _ -> {:error, :thread_not_found}
    end
  end

  defp validate_body(op?, attrs, config) do
    require_body = if(op?, do: config.force_body_op, else: config.force_body)

    if require_body and is_nil(trim_to_nil(attrs["body"])) do
      {:error, :body_required}
    else
      :ok
    end
  end

  defp validate_upload(op?, attrs, config) do
    upload = Map.get(attrs, "file")
    upload_metadata = Map.get(attrs, "__upload_metadata__")

    cond do
      op? and config.force_image_op and is_nil(upload) ->
        {:error, :file_required}

      is_nil(upload) ->
        :ok

      true ->
        with :ok <- validate_upload_type(upload, upload_metadata, config),
             :ok <- validate_upload_size(upload_metadata, config) do
          :ok
        end
    end
  end

  defp validate_upload_type(%Plug.Upload{} = upload, nil, config),
    do:
      validate_upload_type(
        upload,
        %{ext: upload.filename |> Path.extname() |> String.downcase()},
        config
      )

  defp validate_upload_type(_upload, %{ext: ext}, config) do
    allowed = Enum.map(config.allowed_ext_files || [], &String.downcase/1)

    if ext in allowed do
      :ok
    else
      {:error, :invalid_file_type}
    end
  end

  defp validate_upload_size(nil, _config), do: {:error, :upload_failed}

  defp validate_upload_size(upload_metadata, config) do
    max_filesize = config.max_filesize

    if is_integer(max_filesize) and max_filesize > 0 and upload_metadata.file_size > max_filesize do
      {:error, :file_too_large}
    else
      :ok
    end
  end

  defp validate_image_dimensions(attrs, _config)
       when not is_map_key(attrs, "__upload_metadata__"),
       do: :ok

  defp validate_image_dimensions(attrs, config) do
    width = get_in(attrs, ["__upload_metadata__", :image_width]) || 0
    height = get_in(attrs, ["__upload_metadata__", :image_height]) || 0

    cond do
      width < 1 or height < 1 ->
        {:error, :invalid_image}

      config.max_image_width not in [0, nil] and width > config.max_image_width ->
        {:error, :image_too_large}

      config.max_image_height not in [0, nil] and height > config.max_image_height ->
        {:error, :image_too_large}

      true ->
        :ok
    end
  end

  defp validate_delete_password(%Post{password: stored_password}, provided_password) do
    if trim_to_nil(stored_password) == provided_password and not is_nil(provided_password) do
      :ok
    else
      {:error, :invalid_password}
    end
  end

  defp validate_reply_limit(_board, nil, _config, _repo), do: :ok

  defp validate_reply_limit(board, thread, config, repo) do
    if config.reply_hard_limit in [0, nil] do
      :ok
    else
      replies =
        repo.aggregate(
          from(post in Post, where: post.board_id == ^board.id and post.thread_id == ^thread.id),
          :count,
          :id
        )

      if replies >= config.reply_hard_limit, do: {:error, :reply_hard_limit}, else: :ok
    end
  end

  defp validate_image_limit(_board, nil, _attrs, _config, _repo), do: :ok

  defp validate_image_limit(_board, _thread, attrs, _config, _repo)
       when not is_map_key(attrs, "file"),
       do: :ok

  defp validate_image_limit(_board, _thread, %{"file" => nil}, _config, _repo), do: :ok

  defp validate_image_limit(board, thread, _attrs, config, repo) do
    if config.image_hard_limit in [0, nil] do
      :ok
    else
      images =
        repo.aggregate(
          from(
            post in Post,
            where:
              post.board_id == ^board.id and
                (post.id == ^thread.id or post.thread_id == ^thread.id) and
                not is_nil(post.file_path)
          ),
          :count,
          :id
        )

      if images >= config.image_hard_limit, do: {:error, :image_hard_limit}, else: :ok
    end
  end

  defp validate_duplicate_upload(_board, _thread, attrs, _config, _repo)
       when not is_map_key(attrs, "__upload_metadata__"),
       do: :ok

  defp validate_duplicate_upload(_board, thread, attrs, config, repo) do
    md5 = get_in(attrs, ["__upload_metadata__", :file_md5])

    case config.duplicate_file_mode do
      "global" ->
        duplicate? =
          repo.exists?(
            from post in Post, where: post.file_md5 == ^md5 and not is_nil(post.file_md5)
          )

        if duplicate?, do: {:error, :duplicate_file}, else: :ok

      "thread" when not is_nil(thread) ->
        duplicate? =
          repo.exists?(
            from post in Post,
              where:
                (post.id == ^thread.id or post.thread_id == ^thread.id) and
                  post.file_md5 == ^md5 and not is_nil(post.file_md5)
          )

        if duplicate?, do: {:error, :duplicate_file}, else: :ok

      _ ->
        :ok
    end
  end

  defp maybe_bump_thread(nil, _attrs, _config, _repo, _now), do: :ok

  defp maybe_bump_thread(thread, attrs, config, repo, now) do
    email = String.downcase(attrs["email"] || "")
    should_bump = email != "sage" and not thread.sage and bump_allowed?(thread, config, repo)

    if should_bump do
      repo.update_all(
        from(post in Post, where: post.id == ^thread.id),
        set: [bump_at: now]
      )
    else
      {0, nil}
    end

    :ok
  end

  defp bump_allowed?(thread, config, repo) do
    if config.reply_limit in [0, nil] do
      true
    else
      replies =
        repo.aggregate(from(post in Post, where: post.thread_id == ^thread.id), :count, :id)

      replies + 1 < config.reply_limit
    end
  end

  defp maybe_cycle_thread(_board, nil, _config, _repo), do: :ok

  defp maybe_cycle_thread(_board, thread, config, repo) do
    if thread.cycle and config.cycle_limit not in [0, nil] do
      replies =
        repo.all(
          from post in Post,
            where: post.thread_id == ^thread.id,
            order_by: [desc: post.inserted_at, desc: post.id],
            offset: ^config.cycle_limit,
            select: post.id
        )

      if replies != [] do
        repo.delete_all(from post in Post, where: post.id in ^replies)
      end
    end

    :ok
  end

  defp normalize_thread_id(value), do: ThreadPaths.parse_thread_id(value)

  defp thread_summary(board, thread, config, repo) do
    preview_count = config.threads_preview

    replies_desc =
      repo.all(
        from post in Post,
          where: post.board_id == ^board.id and post.thread_id == ^thread.id,
          order_by: [desc: post.inserted_at, desc: post.id],
          limit: ^preview_count
      )

    replies = Enum.reverse(replies_desc)

    reply_count =
      repo.aggregate(
        from(post in Post, where: post.board_id == ^board.id and post.thread_id == ^thread.id),
        :count,
        :id
      )

    reply_image_count =
      repo.aggregate(
        from(
          post in Post,
          where:
            post.board_id == ^board.id and post.thread_id == ^thread.id and
              not is_nil(post.file_path)
        ),
        :count,
        :id
      )

    last_modified =
      case replies_desc do
        [latest | _] -> latest.inserted_at
        [] -> thread.inserted_at
      end

    %{
      thread: thread,
      replies: replies,
      reply_count: reply_count,
      image_count: reply_image_count + image_count(thread),
      omitted_posts: max(reply_count - length(replies), 0),
      omitted_images: max(reply_image_count - Enum.count(replies, &image_post?/1), 0),
      last_modified: thread.bump_at || last_modified
    }
  end

  defp post_delete_file_paths(%Post{thread_id: nil, id: thread_id} = thread, repo) do
    reply_paths =
      repo.all(
        from post in Post,
          where: post.thread_id == ^thread_id and not is_nil(post.file_path),
          select: {post.file_path, post.thumb_path}
      )

    [
      thread.file_path,
      thread.thumb_path
      | Enum.flat_map(reply_paths, fn {file_path, thumb_path} -> [file_path, thumb_path] end)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp post_delete_file_paths(%Post{} = post, _repo) do
    Enum.reject([post.file_path, post.thumb_path], &is_nil/1)
  end

  defp image_count(post), do: if(image_post?(post), do: 1, else: 0)
  defp image_post?(%Post{file_path: file_path}), do: is_binary(file_path) and file_path != ""

  defp build_pages(board, total_pages, config) do
    for num <- 1..total_pages do
      %{
        num: num,
        link:
          if num == 1 do
            "/#{board.uri}"
          else
            "/#{board.uri}/#{String.replace(config.file_page, "%d", Integer.to_string(num))}"
          end
      }
    end
  end

  defp maybe_slugify(attrs, config) do
    if config.slugify do
      source = trim_to_nil(attrs["subject"]) || trim_to_nil(attrs["body"]) || ""

      source
      |> String.downcase()
      |> String.replace(~r/<[^>]+>/, "")
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")
      |> String.slice(0, config.slug_max_size)
      |> case do
        "" -> nil
        slug -> slug
      end
    else
      nil
    end
  end
end
