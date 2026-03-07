defmodule EirinchanWeb.ManagePageController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Build
  alias Eirinchan.Installation
  alias Eirinchan.Moderation
  alias Eirinchan.Runtime.Config
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

  def recent_posts(conn, params) do
    with {:ok, moderator} <- ensure_moderator(conn) do
      boards = Moderation.list_accessible_boards(moderator)
      board_filter = params["board"]

      board_ids =
        case board_filter do
          nil -> Enum.map(boards, & &1.id)
          "" -> Enum.map(boards, & &1.id)
          uri -> boards |> Enum.filter(&(&1.uri == uri)) |> Enum.map(& &1.id)
        end

      limit =
        case Integer.parse(to_string(params["limit"] || "25")) do
          {value, _} -> max(value, 1)
          :error -> 25
        end

      posts =
        Eirinchan.Posts.list_recent_posts(
          limit: limit,
          board_ids: board_ids,
          query: params["query"],
          ip_subnet: params["ip"]
        )

      render(conn, :recent_posts,
        moderator: moderator,
        boards: boards,
        posts: posts,
        filters: %{
          "board" => params["board"],
          "query" => params["query"],
          "ip" => params["ip"],
          "limit" => Integer.to_string(limit)
        }
      )
    else
      {:error, :unauthorized} -> redirect(conn, to: ~p"/manage/login")
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

  def update_board(conn, %{"uri" => uri} = params) do
    with {:ok, _moderator} <- ensure_admin(conn),
         board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         {:ok, _board} <- Boards.update_board(board, Map.take(params, ["title", "subtitle"])) do
      conn
      |> put_flash(:info, "Board updated.")
      |> redirect(to: ~p"/manage")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Administrator access required.", params)

      nil ->
        render_dashboard_error(conn, "Board not found.", params, :not_found)

      {:error, %Ecto.Changeset{} = changeset} ->
        render_dashboard_error(conn, format_changeset(changeset), params, :unprocessable_entity)
    end
  end

  def delete_board(conn, %{"uri" => uri}) do
    with {:ok, _moderator} <- ensure_admin(conn),
         board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         {:ok, _board} <- Boards.delete_board(board) do
      conn
      |> put_flash(:info, "Board deleted.")
      |> redirect(to: ~p"/manage")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Administrator access required.", %{}, :forbidden)

      nil ->
        render_dashboard_error(conn, "Board not found.", %{}, :not_found)
    end
  end

  def rebuild_board(conn, %{"uri" => uri}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         true <- Moderation.board_access?(moderator, board) or moderator.role == "admin" do
      config = board_config(board, conn.host)

      _result =
        case config.generation_strategy do
          "defer" -> Build.process_pending(board: board, config: config)
          _ -> Build.rebuild_board(board, config: config)
        end

      conn
      |> put_flash(:info, "Board rebuilt.")
      |> redirect(to: ~p"/manage")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      false ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      nil ->
        render_dashboard_error(conn, "Board not found.", %{}, :not_found)
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

  defp render_dashboard_error(conn, message, params, status \\ :forbidden) do
    conn
    |> put_status(status)
    |> render(:dashboard,
      moderator: conn.assigns[:current_moderator],
      boards: Moderation.list_accessible_boards(conn.assigns[:current_moderator]),
      error: message,
      params: Map.take(stringify(params), ["uri", "title", "subtitle"])
    )
  end

  defp format_changeset(changeset) do
    changeset.errors
    |> Enum.map_join(", ", fn {field, {message, _opts}} -> "#{field} #{message}" end)
  end

  defp board_config(board_record, request_host) do
    Config.compose(nil, %{}, board_record.config_overrides || %{},
      board: Eirinchan.Boards.BoardRecord.to_board(board_record),
      request_host: request_host
    )
  end
end
