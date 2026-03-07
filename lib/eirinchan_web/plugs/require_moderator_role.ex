defmodule EirinchanWeb.Plugs.RequireModeratorRole do
  import Plug.Conn

  @role_rank %{
    "janitor" => 1,
    "mod" => 2,
    "admin" => 3
  }

  def init(opts), do: opts

  def call(%Plug.Conn{assigns: %{current_moderator: %{role: role}}} = conn, opts) do
    required_role = Keyword.fetch!(opts, :role)

    if Map.get(@role_rank, role, 0) >= Map.get(@role_rank, required_role, 0) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "forbidden"})
      |> halt()
    end
  end

  def call(conn, _opts) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "unauthorized"})
    |> halt()
  end
end
