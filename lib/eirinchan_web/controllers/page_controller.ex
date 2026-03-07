defmodule EirinchanWeb.PageController do
  use EirinchanWeb, :controller

  alias Eirinchan.Announcement
  alias Eirinchan.Boards
  alias Eirinchan.CustomPages
  alias Eirinchan.Installation
  alias Eirinchan.News

  def home(conn, _params) do
    if Installation.setup_required?() do
      redirect(conn, to: ~p"/setup")
    else
      render(conn, :home,
        layout: false,
        boards: Boards.list_boards(),
        announcement: Announcement.current(),
        custom_pages: CustomPages.list_pages(),
        news_entries: News.list_entries(limit: 5)
      )
    end
  end

  def news(conn, _params) do
    if Installation.setup_required?() do
      redirect(conn, to: ~p"/setup")
    else
      render(conn, :news,
        layout: false,
        boards: Boards.list_boards(),
        announcement: Announcement.current(),
        custom_pages: CustomPages.list_pages(),
        news_entries: News.list_entries()
      )
    end
  end

  def page(conn, %{"slug" => slug}) do
    if Installation.setup_required?() do
      redirect(conn, to: ~p"/setup")
    else
      case CustomPages.get_page_by_slug(slug) do
        nil ->
          send_resp(conn, :not_found, "Page not found")

        page ->
          render(conn, :page,
            layout: false,
            boards: Boards.list_boards(),
            announcement: Announcement.current(),
            custom_pages: CustomPages.list_pages(),
            page: page
          )
      end
    end
  end
end
