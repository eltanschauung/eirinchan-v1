defmodule EirinchanWeb.BoardController do
  use EirinchanWeb, :controller

  alias Eirinchan.Posts

  plug EirinchanWeb.Plugs.LoadBoard when action in [:show]

  def show(conn, _params) do
    board = conn.assigns.current_board
    threads = Posts.list_threads(board)

    render(conn, :show, board: board, threads: threads)
  end
end
