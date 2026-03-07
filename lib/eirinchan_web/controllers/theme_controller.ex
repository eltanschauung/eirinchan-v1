defmodule EirinchanWeb.ThemeController do
  use EirinchanWeb, :controller

  alias EirinchanWeb.ThemeRegistry

  def update(conn, %{"theme" => theme} = params) do
    selected_theme =
      if ThemeRegistry.valid_theme?(theme) do
        theme
      else
        ThemeRegistry.default_theme()
      end

    return_to = safe_return_to(params["return_to"])

    conn
    |> put_resp_cookie("theme", selected_theme, max_age: 60 * 60 * 24 * 365, path: "/")
    |> redirect(to: return_to)
  end

  defp safe_return_to(nil), do: "/"
  defp safe_return_to(""), do: "/"

  defp safe_return_to(path) do
    if String.starts_with?(path, "/") do
      path
    else
      "/"
    end
  end
end
