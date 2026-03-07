defmodule EirinchanWeb.PageController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Installation
  alias Eirinchan.News

  def home(conn, _params) do
    if Installation.setup_required?() do
      redirect(conn, to: ~p"/setup")
    else
      render(conn, :home,
        layout: false,
        boards: Boards.list_boards(),
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
        news_entries: News.list_entries()
      )
    end
  end
end
