defmodule EirinchanWeb.PageControllerTest do
  use EirinchanWeb.ConnCase

  test "GET /", %{conn: conn} do
    moderator_fixture()
    _board = board_fixture(%{uri: "tech", title: "Technology"})

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
    assert page =~ "Maintenance"
  end

  test "GET / redirects to setup when no admin exists", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/setup"
  end

  test "GET /news renders public news entries", %{conn: conn} do
    author = moderator_fixture(%{username: "editor"})

    {:ok, _entry} =
      Eirinchan.News.create_entry(%{title: "Launch", body: "Board online", mod_user_id: author.id})

    conn = get(conn, ~p"/news")
    page = html_response(conn, 200)
    assert page =~ "News"
    assert page =~ "Launch"
    assert page =~ "Board online"
    assert page =~ "editor"
  end
end
