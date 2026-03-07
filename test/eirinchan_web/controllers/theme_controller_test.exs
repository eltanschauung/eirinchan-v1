defmodule EirinchanWeb.ThemeControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "theme update stores the selected theme cookie and redirects back", %{conn: conn} do
    conn =
      post(conn, "/theme", %{
        "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
        "theme" => "vichan",
        "return_to" => "/search"
      })

    assert redirected_to(conn) == "/search"
    assert conn.resp_cookies["theme"].value == "vichan"
  end

  test "theme update falls back to the default theme for invalid values", %{conn: conn} do
    conn =
      post(conn, "/theme", %{
        "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
        "theme" => "not-a-theme",
        "return_to" => "https://example.test/elsewhere"
      })

    assert redirected_to(conn) == "/"
    assert conn.resp_cookies["theme"].value == "default"
  end
end
