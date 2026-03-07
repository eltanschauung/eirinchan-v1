defmodule EirinchanWeb.ApiController do
  use EirinchanWeb, :controller

  alias Eirinchan.Api
  alias Eirinchan.Posts

  plug EirinchanWeb.Plugs.LoadBoard

  def page(conn, %{"page_num" => page_num}) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config

    with {:ok, page_data} <-
           Posts.list_threads_page(board, String.to_integer(page_num) + 1, config: config) do
      json(conn, Api.page_json(page_data))
    else
      {:error, :not_found} -> send_resp(conn, :not_found, "Page not found")
    end
  end

  def catalog(conn, _params) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config
    {:ok, first_page} = Posts.list_threads_page(board, 1, config: config)

    pages =
      Enum.map(1..first_page.total_pages, fn page ->
        {:ok, page_data} = Posts.list_threads_page(board, page, config: config)
        page_data
      end)

    json(conn, Api.catalog_json(pages))
  end

  def threads(conn, _params) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config
    {:ok, first_page} = Posts.list_threads_page(board, 1, config: config)

    pages =
      Enum.map(1..first_page.total_pages, fn page ->
        {:ok, page_data} = Posts.list_threads_page(board, page, config: config)
        page_data
      end)

    json(conn, Api.catalog_json(pages, threads_page: true))
  end

  def thread(conn, %{"thread_id" => thread_id}) do
    board = conn.assigns.current_board

    case Posts.get_thread_view(board, thread_id) do
      {:ok, summary} -> json(conn, Api.thread_json(summary))
      {:error, :not_found} -> send_resp(conn, :not_found, "Thread not found")
    end
  end
end
