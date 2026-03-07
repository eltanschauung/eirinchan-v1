defmodule EirinchanWeb.Plugs.FetchTheme do
  @moduledoc false

  import Plug.Conn

  alias EirinchanWeb.ThemeRegistry

  def init(opts), do: opts

  def call(conn, _opts) do
    theme_name =
      conn.cookies["theme"]
      |> normalize_theme()

    theme = ThemeRegistry.fetch(theme_name) || ThemeRegistry.fetch(ThemeRegistry.default_theme())

    conn
    |> assign(:theme_name, theme_name)
    |> assign(:theme_stylesheet, theme.stylesheet)
    |> assign(:theme_options, ThemeRegistry.all())
  end

  defp normalize_theme(name) do
    if ThemeRegistry.valid_theme?(name) do
      name
    else
      ThemeRegistry.default_theme()
    end
  end
end
