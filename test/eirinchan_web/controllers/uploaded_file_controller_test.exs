defmodule EirinchanWeb.UploadedFileControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "uploaded file route returns not found for missing files", %{conn: conn} do
    board = board_fixture()

    conn = get(conn, "/#{board.uri}/src/missing.png")

    assert response(conn, 404) == "File not found"
  end

  test "thumbnail route returns not found for missing files", %{conn: conn} do
    board = board_fixture()

    conn = get(conn, "/#{board.uri}/thumb/missing.png")

    assert response(conn, 404) == "File not found"
  end
end
