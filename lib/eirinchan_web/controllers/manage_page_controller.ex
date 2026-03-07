defmodule EirinchanWeb.ManagePageController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Build
  alias Eirinchan.Bans
  alias Eirinchan.Installation
  alias Eirinchan.Moderation
  alias Eirinchan.Reports
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

  def reports(conn, %{"uri" => uri}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri) do
      render(conn, :reports,
        moderator: moderator,
        board: board,
        reports: Reports.list_reports(board)
      )
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Board not found.", %{}, :not_found)
    end
  end

  def ip_history(conn, %{"ip" => ip}) do
    with {:ok, moderator} <- ensure_moderator(conn) do
      boards = Moderation.list_accessible_boards(moderator)
      board_ids = Enum.map(boards, & &1.id)

      render(conn, :ip_history,
        moderator: moderator,
        ip: ip,
        board: nil,
        posts: Moderation.list_ip_posts(ip, board_ids: board_ids),
        notes: Moderation.list_ip_notes(ip, board_ids: board_ids)
      )
    else
      {:error, :unauthorized} -> redirect(conn, to: ~p"/manage/login")
    end
  end

  def board_ip_history(conn, %{"uri" => uri, "ip" => ip}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri) do
      render(conn, :ip_history,
        moderator: moderator,
        ip: ip,
        board: board,
        posts: Moderation.list_ip_posts(ip, board_ids: [board.id]),
        notes: Moderation.list_ip_notes(ip, board_id: board.id)
      )
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Board not found.", %{}, :not_found)
    end
  end

  def create_ip_note(conn, %{"uri" => uri, "ip" => ip, "body" => body}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri),
         {:ok, _note} <-
           Moderation.add_ip_note(ip, %{
             body: body,
             board_id: board.id,
             mod_user_id: moderator.id
           }) do
      conn
      |> put_flash(:info, "IP note added.")
      |> redirect(to: "/manage/boards/#{board.uri}/ip/#{ip}/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Board not found.", %{}, :not_found)

      {:error, %Ecto.Changeset{} = changeset} ->
        render_dashboard_error(conn, format_changeset(changeset), %{}, :unprocessable_entity)
    end
  end

  def update_ip_note(conn, %{"uri" => uri, "ip" => ip, "id" => id, "body" => body}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri),
         {:ok, note} <- load_board_note(id, board.id),
         {:ok, _note} <- Moderation.update_ip_note(note, %{body: body}) do
      conn
      |> put_flash(:info, "IP note updated.")
      |> redirect(to: "/manage/boards/#{board.uri}/ip/#{ip}/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "IP note not found.", %{}, :not_found)

      {:error, %Ecto.Changeset{} = changeset} ->
        render_dashboard_error(conn, format_changeset(changeset), %{}, :unprocessable_entity)
    end
  end

  def delete_ip_note(conn, %{"uri" => uri, "ip" => ip, "id" => id}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri),
         {:ok, note} <- load_board_note(id, board.id),
         {:ok, _note} <- Moderation.delete_ip_note(note) do
      conn
      |> put_flash(:info, "IP note deleted.")
      |> redirect(to: "/manage/boards/#{board.uri}/ip/#{ip}/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "IP note not found.", %{}, :not_found)
    end
  end

  def delete_ip_posts(conn, %{"ip" => ip}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, _result} <-
           Moderation.list_accessible_boards(moderator)
           |> then(
             &Eirinchan.Posts.moderate_delete_posts_by_ip(&1, ip,
               config_by_board: config_map(&1, conn.host)
             )
           ) do
      conn
      |> put_flash(:info, "Posts deleted for IP.")
      |> redirect(to: "/manage/ip/#{ip}/browser")
    else
      {:error, :unauthorized} -> redirect(conn, to: ~p"/manage/login")
    end
  end

  def delete_board_ip_posts(conn, %{"uri" => uri, "ip" => ip}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri),
         {:ok, _result} <-
           Eirinchan.Posts.moderate_delete_posts_by_ip(board, ip,
             config: board_config(board, conn.host)
           ) do
      conn
      |> put_flash(:info, "Posts deleted for IP.")
      |> redirect(to: "/manage/boards/#{board.uri}/ip/#{ip}/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Board not found.", %{}, :not_found)
    end
  end

  def dismiss_report(conn, %{"uri" => uri, "id" => id}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri),
         {:ok, _report} <- Reports.dismiss_report(board, id) do
      conn
      |> put_flash(:info, "Report dismissed.")
      |> redirect(to: "/manage/boards/#{board.uri}/reports/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Report not found.", %{}, :not_found)
    end
  end

  def dismiss_reports_for_post(conn, %{"uri" => uri, "post_id" => post_id}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri),
         {:ok, _count} <- Reports.dismiss_reports_for_post(board, post_id) do
      conn
      |> put_flash(:info, "Reports dismissed.")
      |> redirect(to: "/manage/boards/#{board.uri}/reports/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Post not found.", %{}, :not_found)
    end
  end

  def ban_appeals(conn, %{"uri" => uri}) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri) do
      render(conn, :ban_appeals,
        moderator: moderator,
        board: board,
        appeals: Bans.list_appeals(board_id: board.id)
      )
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Board not found.", %{}, :not_found)
    end
  end

  def resolve_ban_appeal(conn, %{"uri" => uri, "id" => id} = params) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, board} <- load_accessible_board(moderator, uri),
         appeal when not is_nil(appeal) <- Bans.get_appeal(id),
         true <- appeal.ban && appeal.ban.board_id == board.id,
         {:ok, _appeal} <-
           Bans.resolve_appeal(appeal.id, %{
             status: Map.get(params, "status", "resolved"),
             resolution_note: params["resolution_note"]
           }) do
      conn
      |> put_flash(:info, "Appeal updated.")
      |> redirect(to: "/manage/boards/#{board.uri}/ban-appeals/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      nil ->
        render_dashboard_error(conn, "Appeal not found.", %{}, :not_found)

      false ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Appeal not found.", %{}, :not_found)

      {:error, %Ecto.Changeset{} = changeset} ->
        render_dashboard_error(conn, format_changeset(changeset), %{}, :unprocessable_entity)
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

  defp load_accessible_board(moderator, uri) do
    case Boards.get_board_by_uri(uri) do
      nil ->
        {:error, :not_found}

      board ->
        if moderator.role == "admin" or Moderation.board_access?(moderator, board) do
          {:ok, board}
        else
          {:error, :forbidden}
        end
    end
  end

  defp load_board_note(id, board_id) do
    case Eirinchan.Repo.get(Eirinchan.Moderation.IpNote, id) do
      %{board_id: ^board_id} = note -> {:ok, note}
      _ -> {:error, :not_found}
    end
  end

  defp config_map(boards, host) do
    Map.new(boards, fn board -> {board.id, board_config(board, host)} end)
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
