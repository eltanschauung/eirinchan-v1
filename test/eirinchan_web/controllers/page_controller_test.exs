defmodule EirinchanWeb.PageControllerTest do
  use EirinchanWeb.ConnCase

  test "GET /", %{conn: conn} do
    _board = board_fixture(%{uri: "tech", title: "Technology"})
    conn = get(conn, ~p"/")
    page = html_response(conn, 200)
    assert page =~ "Board index"
    assert page =~ "/ tech /"
    assert page =~ "Feedback"
  end
end
