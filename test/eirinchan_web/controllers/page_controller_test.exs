defmodule EirinchanWeb.PageControllerTest do
  use EirinchanWeb.ConnCase

  test "GET /", %{conn: conn} do
    moderator_fixture()
    _board = board_fixture(%{uri: "tech", title: "Technology"})
    conn = get(conn, ~p"/")
    page = html_response(conn, 200)
    assert page =~ "Board index"
    assert page =~ "/ tech /"
    assert page =~ "Manage"
    assert page =~ "Feedback"
  end

  test "GET / redirects to setup when no admin exists", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/setup"
  end
end
