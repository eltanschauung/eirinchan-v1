defmodule EirinchanWeb.PageControllerTest do
  use EirinchanWeb.ConnCase

  test "GET /", %{conn: conn} do
    moderator_fixture()
    _board = board_fixture(%{uri: "tech", title: "Technology"})
    author = moderator_fixture(%{username: "announce-admin"})
    page_author = moderator_fixture(%{username: "pageadmin"})

    {:ok, _announcement} =
      Eirinchan.Announcement.upsert(%{
        title: "Read this",
        body: "Global notice",
        mod_user_id: author.id
      })

    {:ok, _page} =
      Eirinchan.CustomPages.create_page(%{
        slug: "rules",
        title: "Rules",
        body: "House rules",
        mod_user_id: page_author.id
      })

    {:ok, _entry} =
      Eirinchan.News.create_entry(%{
        title: "Maintenance",
        body: "Tonight",
        mod_user_id: moderator_fixture(%{username: "newsadmin"}).id
      })

    conn = get(conn, ~p"/")
    page = html_response(conn, 200)
    assert page =~ "losers, creeps, whales"
    assert page =~ "/tech/ - Technology"
    assert page =~ "Manage"
    assert page =~ "Feedback"
    assert page =~ "Maintenance"
    assert page =~ "Rules"
    assert page =~ ~s(action="/search")
    assert page =~ ~s(href="/stylesheets/style.css")
    assert page =~ ~s(id="stylesheet" href="/stylesheets/yotsuba.css")
    assert page =~ ~s(data-stylesheet="yotsuba.css")
    assert page =~ ~s(var active_page = "index", board_name = null;)
    assert page =~ ~s(src="/main.js")
    assert page =~ "View News - 02/14/26"
    assert page =~ "We witches are not whale lol."
  end

  test "GET / redirects to setup when no admin exists", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/setup"
  end

  test "GET /news renders public news entries", %{conn: conn} do
    author = moderator_fixture(%{username: "editor"})
    announce_author = moderator_fixture(%{username: "announcer"})
    page_author = moderator_fixture(%{username: "pageeditor"})

    {:ok, _announcement} =
      Eirinchan.Announcement.upsert(%{
        title: "System notice",
        body: "Read first",
        mod_user_id: announce_author.id
      })

    {:ok, _page} =
      Eirinchan.CustomPages.create_page(%{
        slug: "faq",
        title: "FAQ",
        body: "Questions",
        mod_user_id: page_author.id
      })

    {:ok, _entry} =
      Eirinchan.News.create_entry(%{title: "Launch", body: "Board online", mod_user_id: author.id})

    conn = get(conn, ~p"/news")
    page = html_response(conn, 200)
    assert page =~ "News"
    assert page =~ "Launch"
    assert page =~ "Board online"
    assert page =~ "editor"
    assert page =~ "FAQ"
    assert page =~ ~s(class="boardlist")
    assert page =~ ~s(var active_page = "news", board_name = null;)
    assert page =~ "We witches are not whale lol."
  end

  test "GET /pages/:slug renders a custom page", %{conn: conn} do
    author = moderator_fixture(%{username: "pagewriter"})

    {:ok, _page} =
      Eirinchan.CustomPages.create_page(%{
        slug: "help",
        title: "Help",
        body: "How to post",
        mod_user_id: author.id
      })

    conn = get(conn, "/pages/help")
    page = html_response(conn, 200)
    assert page =~ "Help"
    assert page =~ "How to post"
    assert page =~ "pagewriter"
  end

  test "GET /catalog renders a global catalog across boards", %{conn: conn} do
    moderator_fixture()
    board = board_fixture(%{uri: "tea#{System.unique_integer([:positive])}", title: "Tea"})

    other_board =
      board_fixture(%{uri: "meta#{System.unique_integer([:positive])}", title: "Meta"})

    thread_fixture(board, %{subject: "Tea thread", body: "Green tea"})
    thread_fixture(other_board, %{subject: "Meta thread", body: "Board ops"})

    page =
      conn
      |> get("/catalog")
      |> html_response(200)

    assert page =~ "Global Catalog"
    assert page =~ "Tea thread"
    assert page =~ "Meta thread"
  end

  test "GET /ukko renders aggregated board threads", %{conn: conn} do
    moderator_fixture()
    board = board_fixture(%{uri: "tea#{System.unique_integer([:positive])}", title: "Tea"})
    thread_fixture(board, %{subject: "Tea ukko", body: "Ukko body"})

    page =
      conn
      |> get("/ukko")
      |> html_response(200)

    assert page =~ "Ukko"
    assert page =~ "Tea ukko"
    assert page =~ board.uri
  end

  test "GET /recent renders recent posts across boards", %{conn: conn} do
    moderator_fixture()
    board = board_fixture(%{uri: "tea#{System.unique_integer([:positive])}", title: "Tea"})
    thread = thread_fixture(board, %{subject: "Recent thread", body: "Opening"})
    reply_fixture(board, thread, %{body: "Recent reply"})

    page =
      conn
      |> get("/recent")
      |> html_response(200)

    assert page =~ "Recent Posts"
    assert page =~ "Recent reply"
    assert page =~ board.uri
    assert page =~ ~s(class="boardlist")
  end

  test "GET /sitemap.xml renders board and thread urls", %{conn: conn} do
    moderator_fixture()
    board = board_fixture(%{uri: "tea#{System.unique_integer([:positive])}", title: "Tea"})
    thread = thread_fixture(board, %{subject: "Mapped", body: "XML body"})

    xml =
      conn
      |> get("/sitemap.xml")
      |> response(200)

    assert xml =~ "<?xml version=\"1.0\""
    assert xml =~ "<loc>/#{board.uri}</loc>"
    assert xml =~ "<loc>/#{board.uri}/catalog.html</loc>"
    assert xml =~ "<loc>/#{board.uri}/res/#{thread.id}.html</loc>"
  end
end
