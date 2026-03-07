defmodule EirinchanWeb.ManageSessionControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "login creates a moderator session and logout clears it", %{conn: conn} do
    moderator = moderator_fixture(%{username: "admin", password: "secret123"})

    login_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post("/manage/login", %{"username" => moderator.username, "password" => "secret123"})

    assert %{"data" => %{"id" => id, "username" => "admin", "role" => "admin"}} =
             json_response(login_conn, 200)

    session_conn =
      login_conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> get("/manage/session")

    assert %{"data" => %{"id" => ^id, "username" => "admin"}} = json_response(session_conn, 200)

    logout_conn =
      login_conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> delete("/manage/logout")

    assert %{"status" => "ok"} = json_response(logout_conn, 200)

    unauthorized_conn =
      logout_conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> get("/manage/session")

    assert %{"error" => "unauthorized"} = json_response(unauthorized_conn, 401)
  end

  test "manage routes reject anonymous requests", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/manage/boards")

    assert %{"error" => "unauthorized"} = json_response(conn, 401)
  end

  test "login rejects invalid credentials", %{conn: conn} do
    moderator_fixture(%{username: "admin", password: "secret123"})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post("/manage/login", %{"username" => "admin", "password" => "wrong"})

    assert %{"error" => "invalid_credentials"} = json_response(conn, 401)
  end

  test "role hierarchy gates read-only, moderator, and admin manage routes", %{conn: conn} do
    board = board_fixture()
    thread = thread_fixture(board)
    janitor = moderator_fixture(%{role: "janitor"})
    mod = moderator_fixture(%{role: "mod"})
    other_board = board_fixture()

    grant_board_access_fixture(janitor, board)
    grant_board_access_fixture(mod, board)

    janitor_conn =
      conn
      |> login_moderator(janitor)
      |> put_req_header("accept", "application/json")

    assert %{"data" => [%{"uri" => uri}]} =
             janitor_conn
             |> get("/manage/boards")
             |> json_response(200)

    assert uri == board.uri

    assert %{"error" => "forbidden"} =
             janitor_conn
             |> recycle()
             |> login_moderator(janitor)
             |> put_req_header("accept", "application/json")
             |> patch("/manage/boards/#{board.uri}/threads/#{thread.id}", %{"locked" => "true"})
             |> json_response(403)

    assert %{"error" => "forbidden"} =
             janitor_conn
             |> recycle()
             |> login_moderator(janitor)
             |> put_req_header("accept", "application/json")
             |> get("/manage/boards/#{other_board.uri}")
             |> json_response(403)

    assert %{"data" => %{"locked" => true}} =
             conn
             |> recycle()
             |> login_moderator(mod)
             |> put_req_header("accept", "application/json")
             |> patch("/manage/boards/#{board.uri}/threads/#{thread.id}", %{"locked" => "true"})
             |> json_response(200)

    assert %{"error" => "forbidden"} =
             conn
             |> recycle()
             |> login_moderator(mod)
             |> put_req_header("accept", "application/json")
             |> post("/manage/boards", %{uri: "staff", title: "Staff"})
             |> json_response(403)
  end
end
