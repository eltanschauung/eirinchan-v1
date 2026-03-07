defmodule EirinchanWeb.SetupControllerTest do
  use EirinchanWeb.ConnCase, async: false

  test "shows the setup page when no admin exists", %{conn: conn} do
    page = conn |> get("/setup") |> html_response(200)

    assert page =~ "Eirinchan Setup"
    assert page =~ "Install Eirinchan"
  end

  test "setup rejects missing required fields", %{conn: conn} do
    page =
      conn
      |> post("/setup", %{"database_hostname" => "", "admin_username" => ""})
      |> html_response(200)

    assert page =~ "This field is required."
  end

  test "setup redirects away once an admin exists", %{conn: conn} do
    moderator_fixture()

    conn = get(conn, "/setup")
    assert redirected_to(conn) == "/manage/login"
  end
end
