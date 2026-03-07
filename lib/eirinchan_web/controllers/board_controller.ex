defmodule EirinchanWeb.BoardController do
  use EirinchanWeb, :controller

  alias Eirinchan.Posts

  plug EirinchanWeb.Plugs.LoadBoard when action in [:show]

  def show(conn, _params) do
    board = conn.assigns.current_board
    threads = Posts.list_threads(board)
    config = conn.assigns.current_board_config

    render(conn, :show, board: board, threads: threads, config: config)
  end
end
