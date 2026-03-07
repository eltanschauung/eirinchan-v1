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

  @spec create_post(BoardRecord.t(), map(), keyword()) ::
          {:ok, Post.t(), map()}
          | {:error,
             :thread_not_found
             | :invalid_post_mode
             | :invalid_referer
             | :board_locked
             | :body_required
             | :reply_hard_limit}
          | {:error, Ecto.Changeset.t()}
  def create_post(%BoardRecord{} = board, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    config = Keyword.get(opts, :config, Config.compose())
    request = Keyword.get(opts, :request, %{})
    attrs = normalize_attrs(attrs)
    thread_param = blank_to_nil(Map.get(attrs, "thread"))
    op? = is_nil(thread_param)
    attrs = normalize_post_identity(attrs, config)
    noko = noko?(attrs["email"], config)
    attrs = normalize_noko_email(attrs)

    with :ok <- validate_post_button(op?, attrs, config),
         :ok <- validate_referer(request, config),
         :ok <- validate_board_lock(config),
         {:ok, thread} <- fetch_thread(board, thread_param, repo),
         :ok <- validate_body(op?, attrs, config),
         :ok <- validate_reply_limit(board, thread, config, repo),
         {:ok, post} <- insert_post(board, thread, attrs, repo) do
      _ = Build.rebuild_after_post(board, post, config: config, repo: repo)
      {:ok, post, %{noko: noko}}
    end
  end

  @spec list_threads(BoardRecord.t(), keyword()) :: [Post.t()]
  def list_threads(%BoardRecord{} = board, opts \\ []) do
    config = Keyword.get(opts, :config, Config.compose())
    page = Keyword.get(opts, :page, 1)
    {:ok, page_data} = list_threads_page(board, page, Keyword.put(opts, :config, config))
    Enum.map(page_data.threads, & &1.thread)
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
            order_by: [desc: post.inserted_at],
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
    normalized_thread_id = normalize_thread_id(thread_id)

    case repo.one(
           from post in Post,
             where:
               post.id == ^normalized_thread_id and post.board_id == ^board.id and
                 is_nil(post.thread_id)
         ) do
      nil ->
        {:error, :not_found}

      thread ->
        replies =
          repo.all(
            from post in Post,
              where: post.board_id == ^board.id and post.thread_id == ^thread.id,
              order_by: [asc: post.inserted_at]
          )

        {:ok, [thread | replies]}
    end
  end

  @spec get_thread_view(BoardRecord.t(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, :not_found}
  def get_thread_view(%BoardRecord{} = board, thread_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    with {:ok, [thread | replies]} <- get_thread(board, thread_id, repo: repo) do
      {:ok,
       %{
         thread: thread,
         replies: replies,
         reply_count: length(replies),
         image_count: 0,
         omitted_posts: 0,
         omitted_images: 0,
         last_modified: List.last([thread | replies]).inserted_at
       }}
    end
  end

  defp insert_post(board, nil, attrs, repo) do
    attrs =
      attrs
      |> Map.put("board_id", board.id)
      |> Map.put("thread_id", nil)

    %Post{}
    |> Post.create_changeset(attrs)
    |> repo.insert()
  end

  defp insert_post(board, thread, attrs, repo) do
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

  defp fetch_thread(_board, nil, _repo), do: {:ok, nil}

  defp fetch_thread(board, thread_param, repo) do
    thread_id = normalize_thread_id(thread_param)

    case repo.one(
           from post in Post,
             where:
               post.id == ^thread_id and post.board_id == ^board.id and is_nil(post.thread_id)
         ) do
      nil -> {:error, :thread_not_found}
      thread -> {:ok, thread}
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

  defp normalize_thread_id(value) when is_integer(value), do: value

  defp normalize_thread_id(value) when is_binary(value) do
    value
    |> String.replace_suffix(".html", "")
    |> String.trim()
    |> String.to_integer()
  end

  defp thread_summary(board, thread, config, repo) do
    preview_count = config.threads_preview

    replies_desc =
      repo.all(
        from post in Post,
          where: post.board_id == ^board.id and post.thread_id == ^thread.id,
          order_by: [desc: post.inserted_at],
          limit: ^preview_count
      )

    replies = Enum.reverse(replies_desc)

    reply_count =
      repo.aggregate(
        from(post in Post, where: post.board_id == ^board.id and post.thread_id == ^thread.id),
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
      image_count: 0,
      omitted_posts: max(reply_count - length(replies), 0),
      omitted_images: 0,
      last_modified: last_modified
    }
  end

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
end
