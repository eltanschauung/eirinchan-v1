defmodule EirinchanWeb.BoardController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Build
  alias Eirinchan.Posts

  plug EirinchanWeb.Plugs.LoadBoard when action in [:show]
  plug EirinchanWeb.Plugs.LoadBoard when action in [:show_page]
  plug EirinchanWeb.Plugs.LoadBoard when action in [:catalog]

  def show(conn, _params) do
    render_page(conn, 1)
  end

  def show_page(conn, %{"page_num_html" => page_num_html}) do
    page_num =
      page_num_html
      |> String.replace_suffix(".html", "")
      |> String.to_integer()

    render_page(conn, page_num)
  end

  def catalog(conn, _params) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config
    _ = Build.ensure_indexes(board, config: config)

    case Posts.list_page_data(board, config: config) do
      {:ok, pages} ->
        threads = Enum.flat_map(pages, & &1.threads)

        render(conn, :catalog,
          board: board,
          board_title: board.title,
          threads: threads,
          config: config,
          boards: Boards.list_boards()
        )

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Page not found")
    end
  end

  defp render_page(conn, page) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config
    _ = Build.ensure_indexes(board, config: config)

    case Posts.list_threads_page(board, page, config: config) do
      {:ok, page_data} ->
        render(conn, :show,
          board: board,
          board_title: board.title,
          page_data: page_data,
          config: config,
          boards: Boards.list_boards()
        )

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Page not found")
    end
  end
end
