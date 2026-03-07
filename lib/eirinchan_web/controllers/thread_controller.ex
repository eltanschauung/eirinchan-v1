defmodule EirinchanWeb.ThreadController do
  use EirinchanWeb, :controller

  alias Eirinchan.Posts
  alias Eirinchan.ThreadPaths

  plug EirinchanWeb.Plugs.LoadBoard

  def show(conn, %{"thread_id" => thread_id}) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config

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

          render(conn, :show, board: board, summary: summary, config: config, page_num: page_num)
        end

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Thread not found")
    end
  end
end
