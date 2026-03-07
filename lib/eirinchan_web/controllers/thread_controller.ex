defmodule EirinchanWeb.ThreadController do
  use EirinchanWeb, :controller

  alias Eirinchan.Posts

  plug EirinchanWeb.Plugs.LoadBoard

  def show(conn, %{"thread_id" => thread_id}) do
    board = conn.assigns.current_board

    case Posts.get_thread(board, thread_id) do
      {:ok, [thread | replies]} ->
        render(conn, :show, board: board, thread: thread, replies: replies)

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Thread not found")
    end
  end
end
