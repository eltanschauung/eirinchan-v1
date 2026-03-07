defmodule EirinchanWeb.Plugs.RequirePageTheme do
  @moduledoc false

  import Plug.Conn

  alias Eirinchan.Themes

  def init(opts), do: opts

  def call(conn, opts) do
    theme = Keyword.fetch!(opts, :theme)

    if Themes.page_theme_enabled?(theme) do
      conn
    else
      conn
      |> send_resp(:not_found, "Page not found")
      |> halt()
    end
  end
end
