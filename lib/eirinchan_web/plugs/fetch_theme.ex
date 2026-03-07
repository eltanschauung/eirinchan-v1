defmodule EirinchanWeb.Plugs.FetchTheme do
  @moduledoc false

  import Plug.Conn

  alias EirinchanWeb.ThemeRegistry

  def init(opts), do: opts

  def call(conn, _opts) do
    theme_identifier =
      conn.cookies["theme"]
      |> normalize_theme_identifier()

    public_theme = ThemeRegistry.public_lookup(theme_identifier) || ThemeRegistry.public_default()

    theme =
      ThemeRegistry.fetch(public_theme.name) || ThemeRegistry.fetch(ThemeRegistry.default_theme())

    conn
    |> assign(:theme_name, public_theme.name)
    |> assign(:theme_label, public_theme.label)
    |> assign(:theme_stylesheet, theme.stylesheet)
    |> assign(:theme_options, ThemeRegistry.public_all())
  end

  defp normalize_theme_identifier(name) when is_binary(name), do: String.trim(name)
  defp normalize_theme_identifier(_name), do: ""
end
