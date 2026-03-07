defmodule EirinchanWeb.ManageSessionController do
  use EirinchanWeb, :controller

  alias Eirinchan.Moderation
  alias EirinchanWeb.ManageSecurity

  def create(conn, %{"username" => username, "password" => password}) do
    case Moderation.authenticate(username, password) do
      {:ok, user} ->
        secure_token = ManageSecurity.generate_token()

        conn
        |> put_session(:moderator_user_id, user.id)
        |> put_session(:secure_manage_token, secure_token)
        |> json(%{data: session_data(user, secure_token)})

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
        json(conn, %{data: session_data(user, get_session(conn, :secure_manage_token))})
    end
  end

  def secure_token(conn, _params) do
    case {conn.assigns[:current_moderator], get_session(conn, :secure_manage_token)} do
      {nil, _} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})

      {_user, nil} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})

      {_user, secure_token} ->
        json(conn, %{data: %{secure_token: secure_token}})
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> json(%{status: "ok"})
  end

  defp session_data(user, secure_token) do
    %{
      id: user.id,
      username: user.username,
      role: user.role,
      secure_token: secure_token
    }
  end
end
