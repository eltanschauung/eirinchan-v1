defmodule EirinchanWeb.ManageSessionController do
  use EirinchanWeb, :controller

  alias Eirinchan.Moderation

  def create(conn, %{"username" => username, "password" => password}) do
    case Moderation.authenticate(username, password) do
      {:ok, user} ->
        conn
        |> put_session(:moderator_user_id, user.id)
        |> json(%{data: session_data(user)})

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_credentials"})
    end
  end

  def show(conn, _params) do
    case conn.assigns[:current_moderator] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})

      user ->
        json(conn, %{data: session_data(user)})
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> json(%{status: "ok"})
  end

  defp session_data(user) do
    %{
      id: user.id,
      username: user.username,
      role: user.role
    }
  end
end
