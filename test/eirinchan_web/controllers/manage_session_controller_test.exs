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
end
