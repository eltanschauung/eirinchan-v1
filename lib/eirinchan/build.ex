defmodule Eirinchan.Build do
  @moduledoc """
  Minimal filesystem build pipeline for board index and thread pages.
  """

  alias Eirinchan.Api
  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Posts
  alias Eirinchan.ThreadPaths

  @spec rebuild_after_post(BoardRecord.t(), Eirinchan.Posts.Post.t(), keyword()) ::
          :ok | {:error, term()}
  def rebuild_after_post(%BoardRecord{} = board, post, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    repo = Keyword.get(opts, :repo)
    thread_id = post.thread_id || post.id

    with :ok <- build_thread(board, thread_id, config: config, repo: repo),
         :ok <- build_indexes(board, config: config, repo: repo) do
      :ok
    end
  end

  @spec rebuild_thread_state(BoardRecord.t(), integer(), keyword()) :: :ok | {:error, term()}
  def rebuild_thread_state(%BoardRecord{} = board, thread_id, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    repo = Keyword.get(opts, :repo)

    with :ok <- build_thread(board, thread_id, config: config, repo: repo),
         :ok <- build_indexes(board, config: config, repo: repo) do
      :ok
    end
  end

  @spec rebuild_after_delete(BoardRecord.t(), tuple(), keyword()) :: :ok | {:error, term()}
  def rebuild_after_delete(%BoardRecord{} = board, {:thread, thread}, opts) do
    config = Keyword.fetch!(opts, :config)
    repo = Keyword.get(opts, :repo)

    remove_thread_outputs(board, thread, config)
    build_indexes(board, config: config, repo: repo)
  end

  def rebuild_after_delete(%BoardRecord{} = board, {:reply, thread_id}, opts) do
    config = Keyword.fetch!(opts, :config)
    repo = Keyword.get(opts, :repo)

    with :ok <- build_thread(board, thread_id, config: config, repo: repo),
         :ok <- build_indexes(board, config: config, repo: repo) do
      :ok
    end
  end

  @spec build_thread(BoardRecord.t(), integer(), keyword()) :: :ok | {:error, term()}
  def build_thread(%BoardRecord{} = board, thread_id, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    repo = Keyword.get(opts, :repo)

    case Posts.get_thread_view(board, thread_id, repo: repo) do
      {:ok, summary} ->
        html = render_thread(board, summary)

        output_paths =
          summary.thread
          |> thread_output_filenames(config)
          |> Enum.map(&Path.join([board_root(), board.uri, config.dir.res, &1]))

        with :ok <- write_files(output_paths, html) do
          if get_in(config, [:api, :enabled]) do
            json_output =
              Path.join([board_root(), board.uri, config.dir.res, "#{summary.thread.id}.json"])

            write_file(json_output, Jason.encode!(Api.thread_json(summary)))
          else
            :ok
          end
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @spec build_indexes(BoardRecord.t(), keyword()) :: :ok | {:error, term()}
  def build_indexes(%BoardRecord{} = board, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    repo = Keyword.get(opts, :repo)
    {:ok, page_data_list} = Posts.list_page_data(board, config: config, repo: repo)
    first_page = hd(page_data_list)

    with :ok <- write_index_pages(board, page_data_list, config),
         :ok <- write_catalog_page(board, page_data_list, config),
         :ok <- write_api_pages(board, page_data_list, config) do
      remove_stale_index_pages(board, first_page.total_pages, config)
    end
  end

  @spec board_root() :: String.t()
  def board_root do
    Application.fetch_env!(:eirinchan, :build_output_root)
  end

  defp write_file(path, content) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    case File.write(path, content) do
      :ok -> :ok
      error -> error
    end
  end

  defp write_files(paths, content) do
    Enum.reduce_while(paths, :ok, fn path, :ok ->
      case write_file(path, content) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp write_index_pages(board, page_data_list, config) do
    Enum.reduce_while(page_data_list, :ok, fn page_data, :ok ->
      filename =
        if page_data.page == 1 do
          config.file_index
        else
          String.replace(config.file_page, "%d", Integer.to_string(page_data.page))
        end

      html = render_index(board, page_data, config)
      output = Path.join([board_root(), board.uri, filename])

      case write_file(output, html) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp write_catalog_page(board, page_data_list, config) do
    html = render_catalog(board, page_data_list, config)
    output = Path.join([board_root(), board.uri, config.file_catalog])
    write_file(output, html)
  end

  defp write_api_pages(_board, _page_data_list, %{api: %{enabled: false}}), do: :ok

  defp write_api_pages(board, page_data_list, _config) do
    per_page_results =
      Enum.reduce_while(page_data_list, :ok, fn page_data, :ok ->
        json_path = Path.join([board_root(), board.uri, "#{page_data.page - 1}.json"])
        payload = Jason.encode!(Api.page_json(page_data))

        case write_file(json_path, payload) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)

    with :ok <- per_page_results,
         :ok <-
           write_file(
             Path.join([board_root(), board.uri, "catalog.json"]),
             Jason.encode!(Api.catalog_json(page_data_list))
           ) do
      write_file(
        Path.join([board_root(), board.uri, "threads.json"]),
        Jason.encode!(Api.catalog_json(page_data_list, threads_page: true))
      )
    end
  end

  defp remove_stale_index_pages(board, total_pages, config) do
    if total_pages < config.max_pages do
      Enum.each((total_pages + 1)..config.max_pages, fn page ->
        filename =
          Path.join([
            board_root(),
            board.uri,
            String.replace(config.file_page, "%d", Integer.to_string(page))
          ])

        json_filename = Path.join([board_root(), board.uri, "#{page - 1}.json"])
        _ = File.rm(filename)

        if get_in(config, [:api, :enabled]) do
          _ = File.rm(json_filename)
        end
      end)
    end

    :ok
  end

  defp render_index(board, page_data, config) do
    items =
      Enum.map_join(page_data.threads, "\n", fn summary ->
        title = html_escape(summary.thread.subject || "Thread ##{summary.thread.id}")
        body = html_escape(summary.thread.body || "")
        media = render_media(summary.thread)
        replies = render_preview_replies(summary.replies)
        omitted = render_omitted(summary)
        thread_path = ThreadPaths.thread_path(board, summary.thread, config)
        badges = render_thread_badges(summary.thread)
        delete_form = render_delete_form(board, summary.thread.id)

        ~s(<article id="p#{summary.thread.id}"><h2><a href="#{thread_path}">#{title}</a></h2>#{badges}#{media}<p>#{body}</p>#{delete_form}#{omitted}#{replies}</article>)
      end)

    nav = render_pages(page_data.pages, page_data.page)

    """
    <!doctype html>
    <html>
    <head><meta charset="utf-8"><title>/#{html_escape(board.uri)}/ - #{html_escape(board.title)}</title></head>
    <body>
    <h1>/#{html_escape(board.uri)}/ - #{html_escape(board.title)}</h1>
    #{nav}
    #{items}
    #{nav}
    </body>
    </html>
    """
  end

  defp render_thread(board, summary) do
    replies_html =
      Enum.map_join(summary.replies, "\n", fn reply ->
        subject = html_escape(reply.subject || "Reply ##{reply.id}")
        body = html_escape(reply.body || "")
        media = render_media(reply)
        delete_form = render_delete_form(board, reply.id)

        ~s(<article id="p#{reply.id}"><h3>#{subject}</h3>#{media}<p>#{body}</p>#{delete_form}</article>)
      end)

    """
    <!doctype html>
    <html>
    <head><meta charset="utf-8"><title>/#{html_escape(board.uri)}/ - #{html_escape(summary.thread.subject || "Thread ##{summary.thread.id}")}</title></head>
    <body>
    <article id="p#{summary.thread.id}">
    <h1>/#{html_escape(board.uri)}/ - #{html_escape(summary.thread.subject || "Thread ##{summary.thread.id}")}</h1>
    #{render_thread_badges(summary.thread)}
    #{render_media(summary.thread)}
    <p>#{html_escape(summary.thread.body || "")}</p>
    #{render_delete_form(board, summary.thread.id)}
    </article>
    #{replies_html}
    </body>
    </html>
    """
  end

  defp render_catalog(board, page_data_list, config) do
    items =
      page_data_list
      |> Enum.flat_map(& &1.threads)
      |> Enum.map_join("\n", fn summary ->
        title = html_escape(summary.thread.subject || "Thread ##{summary.thread.id}")
        body = html_escape(summary.thread.body || "")
        media = render_media(summary.thread)
        thread_path = ThreadPaths.thread_path(board, summary.thread, config)
        badges = render_thread_badges(summary.thread)
        delete_form = render_delete_form(board, summary.thread.id)

        ~s(<article id="catalog-#{summary.thread.id}"><h2><a href="#{thread_path}">#{title}</a></h2>#{badges}#{media}<p>#{body}</p>#{delete_form}<p>#{summary.reply_count} replies</p></article>)
      end)

    """
    <!doctype html>
    <html>
    <head><meta charset="utf-8"><title>/#{html_escape(board.uri)}/ - #{html_escape(board.title)} catalog</title></head>
    <body>
    <h1>/#{html_escape(board.uri)}/ - #{html_escape(board.title)}</h1>
    <p><a href="/#{html_escape(board.uri)}">Return</a></p>
    #{items}
    </body>
    </html>
    """
  end

  defp thread_output_filenames(thread, config) do
    canonical = ThreadPaths.thread_filename(thread, config)
    legacy = ThreadPaths.legacy_thread_filename(thread, config)
    Enum.uniq([canonical, legacy])
  end

  defp remove_thread_outputs(board, thread, config) do
    thread
    |> thread_output_filenames(config)
    |> Enum.each(fn filename ->
      _ = File.rm(Path.join([board_root(), board.uri, config.dir.res, filename]))
    end)

    _ = File.rm(Path.join([board_root(), board.uri, config.dir.res, "#{thread.id}.json"]))
    :ok
  end

  defp render_thread_badges(thread) do
    labels =
      []
      |> maybe_add_badge(thread.sticky, "Sticky")
      |> maybe_add_badge(thread.locked, "Locked")
      |> maybe_add_badge(thread.cycle, "Cyclical")
      |> maybe_add_badge(thread.sage, "Bumplocked")

    case labels do
      [] -> ""
      _ -> ~s(<p class="thread-flags">#{Enum.join(labels, " ")}</p>)
    end
  end

  defp maybe_add_badge(labels, true, label), do: labels ++ ["[#{label}]"]
  defp maybe_add_badge(labels, _enabled, _label), do: labels

  defp render_delete_form(board, post_id) do
    ~s(<form class="delete-form" action="/#{board.uri}/post" method="post"><input type="hidden" name="delete_post_id" value="#{post_id}" /><input type="password" name="password" placeholder="Password" /><button type="submit">Delete</button></form>)
  end

  defp render_preview_replies(replies) do
    Enum.map_join(replies, "\n", fn reply ->
      body = html_escape(reply.body || "")
      media = render_media(reply)
      ~s(<div class="reply-preview" id="p#{reply.id}">#{media}<p>#{body}</p></div>)
    end)
  end

  defp render_media(%{file_path: nil}), do: ""

  defp render_media(post) do
    full_src = html_escape(post.file_path)
    thumb_src = html_escape(post.thumb_path || post.file_path)
    label = html_escape(post.file_name || Path.basename(post.file_path))

    ~s(<figure class="post-file"><a href="#{full_src}"><img src="#{thumb_src}" alt="#{label}" loading="lazy" /></a><figcaption><a href="#{full_src}">#{label}</a></figcaption></figure>)
  end

  defp render_omitted(%{omitted_posts: omitted_posts, omitted_images: omitted_images})
       when omitted_posts > 0 do
    suffix =
      if omitted_images > 0 do
        " and #{omitted_images} image replies"
      else
        ""
      end

    ~s(<p class="omitted">#{omitted_posts} posts#{suffix} omitted. Click Reply to view.</p>)
  end

  defp render_omitted(_summary), do: ""

  defp render_pages(pages, current_page) do
    links =
      Enum.map_join(pages, " ", fn page ->
        if page.num == current_page do
          ~s(<strong>#{page.num}</strong>)
        else
          ~s(<a href="#{page.link}">#{page.num}</a>)
        end
      end)

    ~s(<nav class="pages">#{links}</nav>)
  end

  defp html_escape(nil), do: ""

  defp html_escape(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
