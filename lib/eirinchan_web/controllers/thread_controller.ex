defmodule EirinchanWeb.ThreadController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Build
  alias Eirinchan.Posts
  alias Eirinchan.ThreadPaths

  plug EirinchanWeb.Plugs.LoadBoard

  def show(conn, %{"thread_id" => thread_id}) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config
    _ = Build.ensure_thread(board, parse_thread_id(thread_id), config: config)

    case Posts.get_thread_view(board, thread_id) do
      {:ok, summary} ->
        canonical_path = ThreadPaths.thread_path(board, summary.thread, config)

        if conn.request_path != canonical_path do
          redirect(conn, to: canonical_path)
        else
          page_num =
            case Posts.find_thread_page(board, summary.thread.id, config: config) do
              {:ok, value} -> value
              {:error, :not_found} -> 1
            end

          render(conn, :show,
            board: board,
            board_title: board.title,
            summary: summary,
            config: config,
            page_num: page_num,
            boards: Boards.list_boards()
          )
        end

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Thread not found")
    end
  end

  defp parse_thread_id(thread_id) when is_integer(thread_id), do: thread_id

  defp parse_thread_id(thread_id) when is_binary(thread_id) do
    thread_id
    |> String.replace_suffix(".html", "")
    |> String.split("-", parts: 2)
    |> hd()
    |> String.to_integer()
  end
end
