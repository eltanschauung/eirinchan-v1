defmodule EirinchanWeb.ManagePageController do
  use EirinchanWeb, :controller

  alias Eirinchan.Announcement
  alias Eirinchan.Boards
  alias Eirinchan.Build
  alias Eirinchan.Bans
  alias Eirinchan.CustomPages
  alias Eirinchan.Installation
  alias Eirinchan.Moderation
  alias Eirinchan.News
  alias Eirinchan.Reports
  alias Eirinchan.Runtime.Config
  alias Eirinchan.Settings
  alias EirinchanWeb.ManageSecurity
  alias EirinchanWeb.ThemeRegistry

  plug :assign_manage_shell

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
        unread_messages: Moderation.count_unread_messages(moderator),
        announcement: Announcement.current(),
        custom_pages: CustomPages.list_pages(),
        news_entries: News.list_entries(limit: 10),
        error: nil,
        params: %{"uri" => nil, "title" => nil, "subtitle" => nil}
      )
    end
  end

  def config(conn, _params) do
    with {:ok, moderator} <- ensure_admin(conn) do
      render(conn, :config,
        moderator: moderator,
        config_json: Settings.encode_for_edit(Settings.current_instance_config()),
        error: nil
      )
    else
      {:error, :unauthorized} -> redirect(conn, to: ~p"/manage/login")
      {:error, :forbidden} -> render_config_error(conn, "Administrator access required.")
    end
  end

  def messages(conn, _params) do
    with {:ok, moderator} <- ensure_moderator(conn) do
      _ = Moderation.mark_inbox_read(moderator)

      render(conn, :messages,
        moderator: moderator,
        messages: Moderation.list_inbox(moderator),
        recipients: Moderation.list_recipients(moderator),
        error: nil
      )
    else
      {:error, :unauthorized} -> redirect(conn, to: ~p"/manage/login")
    end
  end

  def create_message(conn, params) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, _message} <-
           Moderation.send_message(moderator, %{
             recipient_id: params["recipient_id"],
             subject: params["subject"],
             body: params["body"],
             reply_to_id: params["reply_to_id"]
           }) do
      conn
      |> put_flash(:info, "Message sent.")
      |> redirect(to: ~p"/manage/messages/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:messages,
          moderator: conn.assigns[:current_moderator],
          messages: Moderation.list_inbox(conn.assigns.current_moderator),
          recipients: Moderation.list_recipients(conn.assigns.current_moderator),
          error: format_changeset(changeset)
        )
    end
  end

  def update_config(conn, %{"config_json" => config_json}) do
    with {:ok, _moderator} <- ensure_admin(conn),
         {:ok, _config} <- Settings.update_instance_config_from_json(config_json) do
      conn
      |> put_flash(:info, "Instance config updated.")
      |> redirect(to: ~p"/manage/config/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_config_error(conn, "Administrator access required.")

      {:error, :invalid_json} ->
        render_config_error(
          conn,
          "Config must be valid JSON.",
          :unprocessable_entity,
          config_json
        )
    end
  end

  def board_config(conn, %{"uri" => uri}) do
    with {:ok, moderator} <- ensure_admin(conn),
         board when not is_nil(board) <- Boards.get_board_by_uri(uri) do
      render(conn, :board_config,
        moderator: moderator,
        board: board,
        config_json: Settings.encode_for_edit(board.config_overrides || %{}),
        error: nil
      )
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Administrator access required.", %{}, :forbidden)

      nil ->
        render_dashboard_error(conn, "Board not found.", %{}, :not_found)
    end
  end

  def update_board_config(conn, %{"uri" => uri, "config_json" => config_json}) do
    with {:ok, _moderator} <- ensure_admin(conn),
         board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         {:ok, overrides} <- parse_config_json(config_json),
         {:ok, _board} <- Boards.update_board(board, %{"config_overrides" => overrides}) do
      conn
      |> put_flash(:info, "Board config updated.")
      |> redirect(to: "/manage/boards/#{uri}/config/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Administrator access required.", %{}, :forbidden)

      nil ->
        render_dashboard_error(conn, "Board not found.", %{}, :not_found)

      {:error, :invalid_json} ->
        render_board_config_error(conn, uri, "Config must be valid JSON.", config_json)

      {:error, %Ecto.Changeset{} = changeset} ->
        render_board_config_error(conn, uri, format_changeset(changeset), config_json)
    end
  end

  def news(conn, _params) do
    with {:ok, moderator} <- ensure_moderator(conn) do
      render(conn, :news,
        moderator: moderator,
        news_entries: News.list_entries(),
        error: nil
      )
    else
      {:error, :unauthorized} -> redirect(conn, to: ~p"/manage/login")
    end
  end

  def themes(conn, _params) do
    with {:ok, moderator} <- ensure_admin(conn) do
      render(conn, :themes,
        moderator: moderator,
        themes: ThemeRegistry.all(),
        default_theme: ThemeRegistry.default_theme(),
        error: nil
      )
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Administrator access required.", %{}, :forbidden)
    end
  end

  def create_theme(conn, params) do
    with {:ok, _moderator} <- ensure_admin(conn),
         {:ok, _theme} <-
           Settings.upsert_theme(%{
             name: params["name"],
             label: params["label"],
             stylesheet: params["stylesheet"]
           }) do
      conn
      |> put_flash(:info, "Theme installed.")
      |> redirect(to: ~p"/manage/themes/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Administrator access required.", %{}, :forbidden)

      {:error, :invalid_theme} ->
        render_themes_error(
          conn,
          "Theme requires name, label, and stylesheet.",
          :unprocessable_entity
        )
    end
  end

  defp assign_manage_shell(conn, _opts) do
    conn
    |> assign(:base_stylesheet, "/stylesheets/style.css")
    |> assign(:primary_stylesheet, "/stylesheets/yotsuba.css")
    |> assign(:primary_stylesheet_id, "stylesheet")
    |> assign(:body_class, "8chan vichan is-not-moderator mod-page")
    |> assign(:body_data_stylesheet, "yotsuba.css")
    |> assign(:extra_stylesheets, ["/stylesheets/eirinchan-mod.css"])
    |> assign(:skip_app_stylesheet, true)
    |> assign(:skip_flash_group, true)
    |> assign(:hide_theme_switcher, true)
  end

  def update_theme(conn, %{"name" => _name, "default_theme" => default_theme}) do
    with {:ok, _moderator} <- ensure_admin(conn),
         :ok <- Settings.set_default_theme(default_theme) do
      conn
      |> put_flash(:info, "Default theme updated.")
      |> redirect(to: ~p"/manage/themes/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Administrator access required.", %{}, :forbidden)

      {:error, :invalid_theme} ->
        render_themes_error(conn, "Invalid theme selection.", :unprocessable_entity)
    end
  end

  def update_theme(conn, %{"name" => name} = params) do
    with {:ok, _moderator} <- ensure_admin(conn),
         {:ok, _theme} <-
           Settings.upsert_theme(%{
             name: name,
             label: params["label"],
             stylesheet: params["stylesheet"]
           }) do
      conn
      |> put_flash(:info, "Theme updated.")
      |> redirect(to: ~p"/manage/themes/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Administrator access required.", %{}, :forbidden)

      {:error, :invalid_theme} ->
        render_themes_error(
          conn,
          "Theme requires name, label, and stylesheet.",
          :unprocessable_entity
        )
    end
  end

  def delete_theme(conn, %{"name" => name}) do
    with {:ok, _moderator} <- ensure_admin(conn),
         :ok <- Settings.delete_theme(name) do
      conn
      |> put_flash(:info, "Theme removed.")
      |> redirect(to: ~p"/manage/themes/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Administrator access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_themes_error(conn, "Theme not found.", :not_found)
    end
  end

  def create_news(conn, %{"title" => title, "body" => body}) do
    with {:ok, moderator} <- ensure_news_editor(conn),
         {:ok, _entry} <-
           News.create_entry(%{title: title, body: body, mod_user_id: moderator.id}) do
      conn
      |> put_flash(:info, "News entry created.")
      |> redirect(to: ~p"/manage/news/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_news_error(conn, "Moderator access required.")

      {:error, %Ecto.Changeset{} = changeset} ->
        render_news_error(conn, format_changeset(changeset), :unprocessable_entity)
    end
  end

  def update_news(conn, %{"id" => id, "title" => title, "body" => body}) do
    with {:ok, _moderator} <- ensure_news_editor(conn),
         %News.Entry{} = entry <- News.get_entry(id),
         {:ok, _entry} <- News.update_entry(entry, %{title: title, body: body}) do
      conn
      |> put_flash(:info, "News entry updated.")
      |> redirect(to: ~p"/manage/news/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_news_error(conn, "Moderator access required.")

      nil ->
        render_news_error(conn, "News entry not found.", :not_found)

      {:error, %Ecto.Changeset{} = changeset} ->
        render_news_error(conn, format_changeset(changeset), :unprocessable_entity)
    end
  end

  def delete_news(conn, %{"id" => id}) do
    with {:ok, _moderator} <- ensure_news_editor(conn),
         %News.Entry{} = entry <- News.get_entry(id),
         {:ok, _entry} <- News.delete_entry(entry) do
      conn
      |> put_flash(:info, "News entry deleted.")
      |> redirect(to: ~p"/manage/news/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_news_error(conn, "Moderator access required.")

      nil ->
        render_news_error(conn, "News entry not found.", :not_found)
    end
  end

  def announcement(conn, _params) do
    with {:ok, moderator} <- ensure_moderator(conn) do
      render(conn, :announcement,
        moderator: moderator,
        announcement: Announcement.current(),
        error: nil
      )
    else
      {:error, :unauthorized} -> redirect(conn, to: ~p"/manage/login")
    end
  end

  def upsert_announcement(conn, %{"title" => title, "body" => body}) do
    with {:ok, moderator} <- ensure_news_editor(conn),
         {:ok, _announcement} <-
           Announcement.upsert(%{title: title, body: body, mod_user_id: moderator.id}) do
      conn
      |> put_flash(:info, "Announcement updated.")
      |> redirect(to: ~p"/manage/announcement/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_announcement_error(conn, "Moderator access required.")

      {:error, %Ecto.Changeset{} = changeset} ->
        render_announcement_error(conn, format_changeset(changeset), :unprocessable_entity)
    end
  end

  def delete_announcement(conn, _params) do
    with {:ok, _moderator} <- ensure_news_editor(conn),
         {:ok, _announcement} <- Announcement.delete_current() do
      conn
      |> put_flash(:info, "Announcement removed.")
      |> redirect(to: ~p"/manage/announcement/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_announcement_error(conn, "Moderator access required.")
    end
  end

  def pages(conn, _params) do
    with {:ok, moderator} <- ensure_moderator(conn) do
      render(conn, :pages,
        moderator: moderator,
        pages: CustomPages.list_pages(),
        error: nil
      )
    else
      {:error, :unauthorized} -> redirect(conn, to: ~p"/manage/login")
    end
  end

  def create_page(conn, %{"slug" => slug, "title" => title, "body" => body}) do
    with {:ok, moderator} <- ensure_news_editor(conn),
         {:ok, _page} <-
           CustomPages.create_page(%{
             slug: slug,
             title: title,
             body: body,
             mod_user_id: moderator.id
           }) do
      conn
      |> put_flash(:info, "Custom page created.")
      |> redirect(to: ~p"/manage/pages/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_pages_error(conn, "Moderator access required.")

      {:error, %Ecto.Changeset{} = changeset} ->
        render_pages_error(conn, format_changeset(changeset), :unprocessable_entity)
    end
  end

  def update_page(conn, %{"id" => id, "slug" => slug, "title" => title, "body" => body}) do
    with {:ok, _moderator} <- ensure_news_editor(conn),
         %CustomPages.Page{} = page <- load_custom_page(id),
         {:ok, _page} <- CustomPages.update_page(page, %{slug: slug, title: title, body: body}) do
      conn
      |> put_flash(:info, "Custom page updated.")
      |> redirect(to: ~p"/manage/pages/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_pages_error(conn, "Moderator access required.")

      nil ->
        render_pages_error(conn, "Custom page not found.", :not_found)

      {:error, %Ecto.Changeset{} = changeset} ->
        render_pages_error(conn, format_changeset(changeset), :unprocessable_entity)
    end
  end

  def delete_page(conn, %{"id" => id}) do
    with {:ok, _moderator} <- ensure_news_editor(conn),
         %CustomPages.Page{} = page <- load_custom_page(id),
         {:ok, _page} <- CustomPages.delete_page(page) do
      conn
      |> put_flash(:info, "Custom page deleted.")
      |> redirect(to: ~p"/manage/pages/browser")
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_pages_error(conn, "Moderator access required.")

      nil ->
        render_pages_error(conn, "Custom page not found.", :not_found)
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
        boards: boards,
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
        boards: Moderation.list_accessible_boards(moderator),
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
             config: effective_board_config(board, conn.host)
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

  def move_thread(conn, %{
        "uri" => uri,
        "thread_id" => thread_id,
        "target_board_uri" => target_uri
      }) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, source_board} <- load_accessible_board(moderator, uri),
         {:ok, target_board} <- load_accessible_board(moderator, target_uri),
         {:ok, moved_thread} <-
           Eirinchan.Posts.move_thread(
             source_board,
             thread_id,
             target_board,
             source_config: effective_board_config(source_board, conn.host),
             target_config: effective_board_config(target_board, conn.host)
           ) do
      conn
      |> put_flash(:info, "Thread moved.")
      |> redirect(
        to:
          Eirinchan.ThreadPaths.thread_path(
            target_board,
            moved_thread,
            effective_board_config(target_board, conn.host)
          )
      )
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Move target not found.", %{}, :not_found)

      {:error, %Ecto.Changeset{} = changeset} ->
        render_dashboard_error(conn, format_changeset(changeset), %{}, :unprocessable_entity)
    end
  end

  def move_reply(
        conn,
        %{
          "uri" => uri,
          "post_id" => post_id,
          "target_board_uri" => target_uri,
          "target_thread_id" => target_thread_id
        }
      ) do
    with {:ok, moderator} <- ensure_moderator(conn),
         {:ok, source_board} <- load_accessible_board(moderator, uri),
         {:ok, target_board} <- load_accessible_board(moderator, target_uri),
         {:ok, moved_reply} <-
           Eirinchan.Posts.move_reply(
             source_board,
             post_id,
             target_board,
             target_thread_id,
             source_config: effective_board_config(source_board, conn.host),
             target_config: effective_board_config(target_board, conn.host)
           ) do
      conn
      |> put_flash(:info, "Reply moved.")
      |> redirect(
        to:
          Eirinchan.ThreadPaths.thread_path(
            target_board,
            %Eirinchan.Posts.Post{id: moved_reply.thread_id, slug: nil},
            effective_board_config(target_board, conn.host)
          )
      )
    else
      {:error, :unauthorized} ->
        redirect(conn, to: ~p"/manage/login")

      {:error, :forbidden} ->
        render_dashboard_error(conn, "Board access required.", %{}, :forbidden)

      {:error, :not_found} ->
        render_dashboard_error(conn, "Move target not found.", %{}, :not_found)

      {:error, %Ecto.Changeset{} = changeset} ->
        render_dashboard_error(conn, format_changeset(changeset), %{}, :unprocessable_entity)
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
          unread_messages: Moderation.count_unread_messages(conn.assigns[:current_moderator]),
          announcement: Announcement.current(),
          custom_pages: CustomPages.list_pages(),
          news_entries: News.list_entries(limit: 10),
          error: "Administrator access required.",
          params: Map.take(stringify(params), ["uri", "title", "subtitle"])
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:dashboard,
          moderator: conn.assigns.current_moderator,
          boards: Moderation.list_accessible_boards(conn.assigns.current_moderator),
          unread_messages: Moderation.count_unread_messages(conn.assigns.current_moderator),
          announcement: Announcement.current(),
          custom_pages: CustomPages.list_pages(),
          news_entries: News.list_entries(limit: 10),
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
      config = effective_board_config(board, conn.host)

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

  defp ensure_news_editor(conn) do
    with {:ok, moderator} <- ensure_moderator(conn) do
      if moderator.role in ["admin", "mod"], do: {:ok, moderator}, else: {:error, :forbidden}
    end
  end

  defp stringify(params), do: Enum.into(params, %{}, fn {k, v} -> {to_string(k), v} end)

  defp render_dashboard_error(conn, message, params, status \\ :forbidden) do
    conn
    |> put_status(status)
    |> render(:dashboard,
      moderator: conn.assigns[:current_moderator],
      boards: Moderation.list_accessible_boards(conn.assigns[:current_moderator]),
      unread_messages: Moderation.count_unread_messages(conn.assigns[:current_moderator]),
      announcement: Announcement.current(),
      custom_pages: CustomPages.list_pages(),
      news_entries: News.list_entries(limit: 10),
      error: message,
      params: Map.take(stringify(params), ["uri", "title", "subtitle"])
    )
  end

  defp render_news_error(conn, message, status \\ :forbidden) do
    conn
    |> put_status(status)
    |> render(:news,
      moderator: conn.assigns[:current_moderator],
      news_entries: News.list_entries(),
      error: message
    )
  end

  defp render_announcement_error(conn, message, status \\ :forbidden) do
    conn
    |> put_status(status)
    |> render(:announcement,
      moderator: conn.assigns[:current_moderator],
      announcement: Announcement.current(),
      error: message
    )
  end

  defp render_pages_error(conn, message, status \\ :forbidden) do
    conn
    |> put_status(status)
    |> render(:pages,
      moderator: conn.assigns[:current_moderator],
      pages: CustomPages.list_pages(),
      error: message
    )
  end

  defp render_themes_error(conn, message, status) do
    conn
    |> put_status(status)
    |> render(:themes,
      moderator: conn.assigns[:current_moderator],
      themes: ThemeRegistry.all(),
      default_theme: ThemeRegistry.default_theme(),
      error: message
    )
  end

  defp render_config_error(conn, message, status \\ :forbidden, config_json \\ "{}") do
    conn
    |> put_status(status)
    |> render(:config,
      moderator: conn.assigns[:current_moderator],
      config_json: config_json,
      error: message
    )
  end

  defp render_board_config_error(conn, uri, message, config_json, status \\ :unprocessable_entity) do
    conn
    |> put_status(status)
    |> render(:board_config,
      moderator: conn.assigns[:current_moderator],
      board: Boards.get_board_by_uri(uri),
      config_json: config_json,
      error: message
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
    Map.new(boards, fn board -> {board.id, effective_board_config(board, host)} end)
  end

  defp load_custom_page(id), do: Eirinchan.Repo.get(Eirinchan.CustomPages.Page, id)

  defp format_changeset(changeset) do
    changeset.errors
    |> Enum.map_join(", ", fn {field, {message, _opts}} -> "#{field} #{message}" end)
  end

  defp effective_board_config(board_record, request_host) do
    Config.compose(nil, Settings.current_instance_config(), board_record.config_overrides || %{},
      board: Eirinchan.Boards.BoardRecord.to_board(board_record),
      request_host: request_host
    )
  end

  defp parse_config_json(raw_json) when is_binary(raw_json) do
    with {:ok, decoded} <- Jason.decode(raw_json),
         true <- is_map(decoded) do
      {:ok, Config.normalize_override_keys(decoded)}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      false -> {:error, :invalid_json}
    end
  end
end
