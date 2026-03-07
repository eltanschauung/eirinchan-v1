defmodule Eirinchan.Build do
  @moduledoc """
  Minimal filesystem build pipeline for board index and thread pages.
  """

  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Posts

  @spec rebuild_after_post(BoardRecord.t(), Eirinchan.Posts.Post.t(), keyword()) ::
          :ok | {:error, term()}
  def rebuild_after_post(%BoardRecord{} = board, post, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    repo = Keyword.get(opts, :repo)
    thread_id = post.thread_id || post.id

    with :ok <- build_thread(board, thread_id, config: config, repo: repo),
         :ok <- build_index(board, config: config, repo: repo) do
      :ok
    end
  end

  @spec build_thread(BoardRecord.t(), integer(), keyword()) :: :ok | {:error, term()}
  def build_thread(%BoardRecord{} = board, thread_id, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    repo = Keyword.get(opts, :repo)

    case Posts.get_thread(board, thread_id, repo: repo) do
      {:ok, [thread | replies]} ->
        html = render_thread(board, thread, replies)
        output = Path.join([board_root(), board.uri, config.dir.res, "#{thread.id}.html"])
        write_file(output, html)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @spec build_index(BoardRecord.t(), keyword()) :: :ok | {:error, term()}
  def build_index(%BoardRecord{} = board, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    repo = Keyword.get(opts, :repo)
    threads = Posts.list_threads(board, repo: repo)

    html = render_index(board, threads)
    output = Path.join([board_root(), board.uri, config.file_index])
    write_file(output, html)
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

  defp render_index(board, threads) do
    items =
      Enum.map_join(threads, "\n", fn thread ->
        title = html_escape(thread.subject || "Thread ##{thread.id}")
        body = html_escape(thread.body || "")

        ~s(<article id="p#{thread.id}"><h2><a href="/#{board.uri}/res/#{thread.id}.html">#{title}</a></h2><p>#{body}</p></article>)
      end)

    """
    <!doctype html>
    <html>
    <head><meta charset="utf-8"><title>/#{html_escape(board.uri)}/ - #{html_escape(board.title)}</title></head>
    <body>
    <h1>/#{html_escape(board.uri)}/ - #{html_escape(board.title)}</h1>
    #{items}
    </body>
    </html>
    """
  end

  defp render_thread(board, thread, replies) do
    replies_html =
      Enum.map_join(replies, "\n", fn reply ->
        subject = html_escape(reply.subject || "Reply ##{reply.id}")
        body = html_escape(reply.body || "")
        ~s(<article id="p#{reply.id}"><h3>#{subject}</h3><p>#{body}</p></article>)
      end)

    """
    <!doctype html>
    <html>
    <head><meta charset="utf-8"><title>/#{html_escape(board.uri)}/ - #{html_escape(thread.subject || "Thread ##{thread.id}")}</title></head>
    <body>
    <article id="p#{thread.id}">
    <h1>/#{html_escape(board.uri)}/ - #{html_escape(thread.subject || "Thread ##{thread.id}")}</h1>
    <p>#{html_escape(thread.body || "")}</p>
    </article>
    #{replies_html}
    </body>
    </html>
    """
  end

  defp html_escape(nil), do: ""

  defp html_escape(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
