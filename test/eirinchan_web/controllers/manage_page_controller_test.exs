defmodule EirinchanWeb.ManagePageControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "login page renders and browser login redirects to the dashboard", %{conn: conn} do
    moderator = moderator_fixture(%{username: "admin", password: "secret123"})

    login_page = conn |> get("/manage/login") |> html_response(200)
    assert login_page =~ "Moderator Login"

    conn =
      conn
      |> recycle()
      |> post("/manage/login/browser", %{
        "username" => moderator.username,
        "password" => "secret123"
      })

    assert redirected_to(conn) == "/manage"

    dashboard =
      conn
      |> recycle()
      |> get("/manage")
      |> html_response(200)

    assert dashboard =~ "Signed in as"
    assert dashboard =~ moderator.username
  end

  test "browser dashboard redirects to setup when no admin exists", %{conn: conn} do
    conn = get(conn, "/manage/login")
    assert redirected_to(conn) == "/setup"
  end

  test "admin browser dashboard creates boards", %{conn: conn} do
    moderator = moderator_fixture(%{role: "admin"})

    conn =
      conn
      |> login_moderator(moderator)
      |> post("/manage/boards/browser", %{"uri" => "tea", "title" => "Tea", "subtitle" => "Board"})

    assert redirected_to(conn) == "/tea"

    board_page =
      conn
      |> recycle()
      |> get("/tea")
      |> html_response(200)

    assert board_page =~ "/ tea / - Tea"
  end
end
