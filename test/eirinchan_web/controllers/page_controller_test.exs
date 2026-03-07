defmodule EirinchanWeb.PageControllerTest do
  use EirinchanWeb.ConnCase

  test "GET /", %{conn: conn} do
    moderator_fixture()
    _board = board_fixture(%{uri: "tech", title: "Technology"})
    author = moderator_fixture(%{username: "announce-admin"})

    {:ok, _announcement} =
      Eirinchan.Announcement.upsert(%{
        title: "Read this",
        body: "Global notice",
        mod_user_id: author.id
      })

    {:ok, _entry} =
      Eirinchan.News.create_entry(%{
        title: "Maintenance",
        body: "Tonight",
        mod_user_id: moderator_fixture(%{username: "newsadmin"}).id
      })

    conn = get(conn, ~p"/")
    page = html_response(conn, 200)
    assert page =~ "Board index"
    assert page =~ "/ tech /"
    assert page =~ "Manage"
    assert page =~ "Feedback"
    assert page =~ "Read this"
    assert page =~ "Global notice"
    assert page =~ "Maintenance"
  end

  test "GET / redirects to setup when no admin exists", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/setup"
  end

  test "GET /news renders public news entries", %{conn: conn} do
    author = moderator_fixture(%{username: "editor"})
    announce_author = moderator_fixture(%{username: "announcer"})

    {:ok, _announcement} =
      Eirinchan.Announcement.upsert(%{
        title: "System notice",
        body: "Read first",
        mod_user_id: announce_author.id
      })

    {:ok, _entry} =
      Eirinchan.News.create_entry(%{title: "Launch", body: "Board online", mod_user_id: author.id})

    conn = get(conn, ~p"/news")
    page = html_response(conn, 200)
    assert page =~ "News"
    assert page =~ "System notice"
    assert page =~ "Read first"
    assert page =~ "Launch"
    assert page =~ "Board online"
    assert page =~ "editor"
  end
end
