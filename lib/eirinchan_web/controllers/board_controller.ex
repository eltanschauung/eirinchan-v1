defmodule EirinchanWeb.BoardController do
  use EirinchanWeb, :controller

  alias Eirinchan.Announcement
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
          layout: false,
          board: board,
          board_title: board.title,
          announcement: Announcement.current(),
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
          layout: false,
          board: board,
          board_title: board.title,
          page_title: "/#{board.uri}/ - #{board.title}",
          announcement: Announcement.current(),
          page_data: page_data,
          config: config,
          boards: Boards.list_boards(),
          body_class: board_body_class(conn),
          body_data_stylesheet: board_data_stylesheet(board),
          extra_stylesheets: board_extra_stylesheets(board),
          hide_theme_switcher: true,
          skip_app_stylesheet: true
        )

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Page not found")
    end
  end

  defp board_body_class(conn) do
    moderator_class =
      if conn.assigns[:current_moderator], do: "is-moderator", else: "is-not-moderator"

    "8chan vichan #{moderator_class} active-index"
  end

  defp board_data_stylesheet(%{uri: "bant"}), do: "christmas.css"
  defp board_data_stylesheet(_board), do: nil

  defp board_extra_stylesheets(%{uri: "bant"}), do: ["/stylesheets/christmas.css"]
  defp board_extra_stylesheets(_board), do: []
end
