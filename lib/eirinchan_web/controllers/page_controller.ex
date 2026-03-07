defmodule EirinchanWeb.PageController do
  use EirinchanWeb, :controller

  alias Eirinchan.Announcement
  alias Eirinchan.Boards
  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.CustomPages
  alias Eirinchan.Installation
  alias Eirinchan.News
  alias Eirinchan.Posts
  alias Eirinchan.Runtime.Config
  alias Eirinchan.Settings

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

  def catalog(conn, _params) do
    if Installation.setup_required?() do
      redirect(conn, to: ~p"/setup")
    else
      render(conn, :catalog,
        layout: false,
        boards: Boards.list_boards(),
        announcement: Announcement.current(),
        custom_pages: CustomPages.list_pages(),
        threads: global_catalog_threads()
      )
    end
  end

  def ukko(conn, _params) do
    if Installation.setup_required?() do
      redirect(conn, to: ~p"/setup")
    else
      render(conn, :ukko,
        layout: false,
        boards: Boards.list_boards(),
        announcement: Announcement.current(),
        custom_pages: CustomPages.list_pages(),
        threads: ukko_threads()
      )
    end
  end

  def recent(conn, _params) do
    if Installation.setup_required?() do
      redirect(conn, to: ~p"/setup")
    else
      render(conn, :recent,
        layout: false,
        boards: Boards.list_boards(),
        announcement: Announcement.current(),
        custom_pages: CustomPages.list_pages(),
        posts: Posts.list_recent_posts(limit: 50)
      )
    end
  end

  def sitemap(conn, _params) do
    if Installation.setup_required?() do
      redirect(conn, to: ~p"/setup")
    else
      xml =
        [
          "/",
          "/news",
          "/catalog",
          "/ukko",
          "/recent"
          | sitemap_paths()
        ]
        |> Enum.uniq()
        |> render_sitemap()

      conn
      |> put_resp_content_type("application/xml")
      |> send_resp(200, xml)
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

  defp global_catalog_threads do
    Boards.list_boards()
    |> Enum.flat_map(fn board ->
      config = board_config(board)

      case Posts.list_page_data(board, config: config) do
        {:ok, pages} ->
          Enum.flat_map(pages, fn page ->
            Enum.map(page.threads, &%{board: board, summary: &1})
          end)

        _ ->
          []
      end
    end)
  end

  defp ukko_threads do
    Boards.list_boards()
    |> Enum.flat_map(fn board ->
      config = board_config(board)

      case Posts.list_threads_page(board, 1, config: config) do
        {:ok, page} -> Enum.map(page.threads, &%{board: board, summary: &1})
        _ -> []
      end
    end)
  end

  defp sitemap_paths do
    board_paths =
      Boards.list_boards()
      |> Enum.flat_map(fn board ->
        thread_paths =
          Posts.list_recent_posts(limit: 100, board_ids: [board.id])
          |> Enum.map(&(&1.thread_id || &1.id))
          |> Enum.uniq()
          |> Enum.map(&"/#{board.uri}/res/#{&1}.html")

        ["/#{board.uri}", "/#{board.uri}/catalog.html" | thread_paths]
      end)

    page_paths = Enum.map(CustomPages.list_pages(), &"/pages/#{&1.slug}")

    board_paths ++ page_paths
  end

  defp render_sitemap(paths) do
    entries =
      Enum.map_join(paths, "", fn path ->
        "<url><loc>#{html_escape(path)}</loc></url>"
      end)

    ~s(<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">#{entries}</urlset>)
  end

  defp board_config(%BoardRecord{} = board) do
    Config.compose(nil, Settings.current_instance_config(), board.config_overrides || %{},
      board: BoardRecord.to_board(board)
    )
  end

  defp html_escape(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
