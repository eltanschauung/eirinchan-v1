defmodule EirinchanWeb.LegacyModController do
  use EirinchanWeb, :controller

  def show(conn, _params) do
    case conn.query_string do
      "/themes" ->
        redirect(conn, to: ~p"/manage/themes/browser")

      "/themes/" <> rest ->
        redirect_legacy_theme_path(conn, rest)

      _ -> send_resp(conn, :not_found, "Page not found")
    end
  end

  defp redirect_legacy_theme_path(conn, rest) do
    case String.split(rest, "/") do
      [theme] ->
        redirect(conn, to: "/manage/themes/browser/#{theme}")

      [theme, "rebuild" | _] ->
        redirect(conn, to: "/manage/themes/browser/#{theme}")

      [theme, "uninstall" | _] ->
        redirect(conn, to: "/manage/themes/browser/#{theme}")

      _ ->
        send_resp(conn, :not_found, "Page not found")
    end
  end
end
