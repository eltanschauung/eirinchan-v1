defmodule EirinchanWeb.ManagePageController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Installation
  alias Eirinchan.Moderation
  alias EirinchanWeb.ManageSecurity

  def login(conn, _params) do
    cond do
      Installation.setup_required?() ->
        redirect(conn, to: ~p"/setup")

      conn.assigns[:current_moderator] ->
        redirect(conn, to: ~p"/manage")

      true ->
        render(conn, :login, error: nil, username: nil)
    end
  end

  def create_session(conn, %{"username" => username, "password" => password}) do
    case Moderation.authenticate(username, password) do
      {:ok, moderator} ->
        secure_token = ManageSecurity.generate_token()

        conn
        |> put_session(:moderator_user_id, moderator.id)
        |> put_session(:secure_manage_token, secure_token)
        |> redirect(to: ~p"/manage")

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> render(:login, error: "Invalid credentials.", username: username)
    end
  end

  def dashboard(conn, _params) do
    with {:ok, moderator} <- ensure_moderator(conn) do
      render(conn, :dashboard,
        moderator: moderator,
        boards: Moderation.list_accessible_boards(moderator),
        error: nil,
        params: %{"uri" => nil, "title" => nil, "subtitle" => nil}
      )
    end
  end

  def create_board(conn, params) do
    with {:ok, _moderator} <- ensure_admin(conn),
         {:ok, board} <- Boards.create_board(Map.take(params, ["uri", "title", "subtitle"])) do
      conn
      |> put_flash(:info, "Board created.")
      |> redirect(to: "/#{board.uri}")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> render(:dashboard,
          moderator: conn.assigns[:current_moderator],
          boards: Moderation.list_accessible_boards(conn.assigns[:current_moderator]),
          error: "Administrator access required.",
          params: Map.take(stringify(params), ["uri", "title", "subtitle"])
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:dashboard,
          moderator: conn.assigns.current_moderator,
          boards: Moderation.list_accessible_boards(conn.assigns.current_moderator),
          error: format_changeset(changeset),
          params: Map.take(stringify(params), ["uri", "title", "subtitle"])
        )
    end
  end

  def delete_session(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/manage/login")
  end

  defp ensure_moderator(%Plug.Conn{assigns: %{current_moderator: nil}}),
    do: {:error, :unauthorized}

  defp ensure_moderator(%Plug.Conn{assigns: %{current_moderator: moderator}}),
    do: {:ok, moderator}

  defp ensure_admin(conn) do
    with {:ok, moderator} <- ensure_moderator(conn) do
      if moderator.role == "admin", do: {:ok, moderator}, else: {:error, :forbidden}
    end
  end

  defp stringify(params), do: Enum.into(params, %{}, fn {k, v} -> {to_string(k), v} end)

  defp format_changeset(changeset) do
    changeset.errors
    |> Enum.map_join(", ", fn {field, {message, _opts}} -> "#{field} #{message}" end)
  end
end
