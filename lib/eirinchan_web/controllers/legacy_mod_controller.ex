defmodule EirinchanWeb.LegacyModController do
  use EirinchanWeb, :controller

  def show(conn, _params) do
    case conn.query_string do
      "/themes" -> redirect(conn, to: ~p"/manage/themes/browser")
      _ -> send_resp(conn, :not_found, "Page not found")
    end
  end
end
