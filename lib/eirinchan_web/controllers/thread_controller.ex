defmodule EirinchanWeb.ThreadController do
  use EirinchanWeb, :controller

  alias Eirinchan.Posts

  plug EirinchanWeb.Plugs.LoadBoard

  def show(conn, %{"thread_id" => thread_id}) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config

    case Posts.get_thread_view(board, thread_id) do
      {:ok, summary} ->
        render(conn, :show, board: board, summary: summary, config: config)

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Thread not found")
    end
  end
end
