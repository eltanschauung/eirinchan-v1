defmodule EirinchanWeb.Plugs.RequireModerator do
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{assigns: %{current_moderator: %{}}} = conn, _opts), do: conn

  def call(conn, _opts) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "unauthorized"})
    |> halt()
  end
end
