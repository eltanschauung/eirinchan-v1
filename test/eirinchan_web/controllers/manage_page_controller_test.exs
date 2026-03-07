defmodule EirinchanWeb.ManagePageControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "login page renders and browser login redirects to the dashboard", %{conn: conn} do
    moderator = moderator_fixture(%{username: "admin", password: "secret123"})

    login_page = conn |> get("/manage/login") |> html_response(200)
    assert login_page =~ "Moderator Login"

    conn =
      conn
      |> recycle()
      |> post("/manage/login/browser", %{
        "username" => moderator.username,
        "password" => "secret123"
      })

    assert redirected_to(conn) == "/manage"

    dashboard =
      conn
      |> recycle()
      |> get("/manage")
      |> html_response(200)

    assert dashboard =~ "Signed in as"
    assert dashboard =~ moderator.username
  end

  test "browser dashboard redirects to setup when no admin exists", %{conn: conn} do
    conn = get(conn, "/manage/login")
    assert redirected_to(conn) == "/setup"
  end

  test "admin browser dashboard creates boards", %{conn: conn} do
    moderator = moderator_fixture(%{role: "admin"})

    conn =
      conn
      |> login_moderator(moderator)
      |> post("/manage/boards/browser", %{"uri" => "tea", "title" => "Tea", "subtitle" => "Board"})

    assert redirected_to(conn) == "/tea"

    board_page =
      conn
      |> recycle()
      |> get("/tea")
      |> html_response(200)

    assert board_page =~ "/ tea / - Tea"
  end

  test "admin browser dashboard updates and deletes boards", %{conn: conn} do
    moderator = moderator_fixture(%{role: "admin"})
    board = board_fixture(%{uri: "tea", title: "Tea", subtitle: "Board"})

    update_conn =
      conn
      |> login_moderator(moderator)
      |> patch("/manage/boards/#{board.uri}/browser", %{
        "title" => "Tea Time",
        "subtitle" => "Updated"
      })

    assert redirected_to(update_conn) == "/manage"

    dashboard =
      update_conn
      |> recycle()
      |> login_moderator(moderator)
      |> get("/manage")
      |> html_response(200)

    assert dashboard =~ "Tea Time"
    assert dashboard =~ "Updated"

    delete_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> delete("/manage/boards/#{board.uri}/browser")

    assert redirected_to(delete_conn) == "/manage"
    refute Eirinchan.Boards.get_board_by_uri(board.uri)
  end

  test "browser dashboard can rebuild accessible boards", %{conn: conn} do
    alias Eirinchan.Build
    alias Eirinchan.Posts
    alias Eirinchan.Runtime.Config

    moderator = moderator_fixture(%{role: "admin"})
    board = board_fixture(%{config_overrides: %{generation_strategy: "defer"}})
    File.rm_rf!(Path.join(Build.board_root(), board.uri))
    config = Config.compose(nil, %{}, board.config_overrides, request_host: "example.test")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Deferred body",
                 "subject" => "Deferred subject",
                 "post" => "New Topic"
               },
               config: config,
               request: %{referer: "http://example.test/#{board.uri}/index.html"}
             )

    refute File.exists?(Path.join([Build.board_root(), board.uri, "res", "#{thread.id}.html"]))

    rebuild_conn =
      conn
      |> login_moderator(moderator)
      |> post("/manage/boards/#{board.uri}/browser/rebuild")

    assert redirected_to(rebuild_conn) == "/manage"
    assert File.exists?(Path.join([Build.board_root(), board.uri, "res", "#{thread.id}.html"]))
  end

  test "browser news management creates, updates, and deletes entries", %{conn: conn} do
    moderator = moderator_fixture(%{role: "admin"})

    create_conn =
      conn
      |> login_moderator(moderator)
      |> post("/manage/news/browser", %{"title" => "Launch", "body" => "Site is live"})

    assert redirected_to(create_conn) == "/manage/news/browser"

    news_page =
      create_conn
      |> recycle()
      |> login_moderator(moderator)
      |> get("/manage/news/browser")
      |> html_response(200)

    assert news_page =~ "Manage News"
    assert news_page =~ "Launch"
    assert news_page =~ "Site is live"

    [entry] = Eirinchan.News.list_entries()

    update_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> patch("/manage/news/browser/#{entry.id}", %{
        "title" => "Launch Updated",
        "body" => "Site is more live"
      })

    assert redirected_to(update_conn) == "/manage/news/browser"

    public_news =
      update_conn
      |> recycle()
      |> get("/news")
      |> html_response(200)

    assert public_news =~ "Launch Updated"
    assert public_news =~ "Site is more live"

    delete_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> delete("/manage/news/browser/#{entry.id}")

    assert redirected_to(delete_conn) == "/manage/news/browser"
    assert Eirinchan.News.list_entries() == []
  end

  test "browser announcement management creates, updates, and deletes the site announcement", %{
    conn: conn
  } do
    moderator = moderator_fixture(%{role: "admin"})

    create_conn =
      conn
      |> login_moderator(moderator)
      |> post("/manage/announcement/browser", %{
        "title" => "Banner",
        "body" => "Important notice"
      })

    assert redirected_to(create_conn) == "/manage/announcement/browser"

    announcement_page =
      create_conn
      |> recycle()
      |> login_moderator(moderator)
      |> get("/manage/announcement/browser")
      |> html_response(200)

    assert announcement_page =~ "Manage Announcement"
    assert announcement_page =~ "Banner"
    assert announcement_page =~ "Important notice"

    update_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> post("/manage/announcement/browser", %{
        "title" => "Banner Updated",
        "body" => "Important notice updated"
      })

    assert redirected_to(update_conn) == "/manage/announcement/browser"

    home_page =
      update_conn
      |> recycle()
      |> get("/")
      |> html_response(200)

    assert home_page =~ "Banner Updated"
    assert home_page =~ "Important notice updated"

    delete_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> delete("/manage/announcement/browser")

    assert redirected_to(delete_conn) == "/manage/announcement/browser"
    assert Eirinchan.Announcement.current() == nil
  end

  test "browser recent posts page filters by board, query, and ip", %{conn: conn} do
    moderator = moderator_fixture(%{role: "admin"})
    board = board_fixture(%{uri: "tea", title: "Tea"})
    other_board = board_fixture(%{uri: "meta", title: "Meta"})

    {:ok, matching_post, _meta} =
      Eirinchan.Posts.create_post(
        board,
        %{"body" => "green leaf", "subject" => "teaware", "post" => "New Topic"},
        config: Eirinchan.Runtime.Config.compose(nil, %{}, board.config_overrides),
        request: %{
          referer: "http://example.test/#{board.uri}/index.html",
          remote_ip: {198, 51, 100, 7}
        }
      )

    {:ok, _other_post, _meta} =
      Eirinchan.Posts.create_post(
        other_board,
        %{"body" => "other board", "subject" => "meta", "post" => "New Topic"},
        config: Eirinchan.Runtime.Config.compose(nil, %{}, other_board.config_overrides),
        request: %{
          referer: "http://example.test/#{other_board.uri}/index.html",
          remote_ip: {203, 0, 113, 9}
        }
      )

    page =
      conn
      |> login_moderator(moderator)
      |> get("/manage/recent-posts/browser", %{
        "board" => board.uri,
        "query" => "leaf",
        "ip" => "198.51.100.7",
        "limit" => "10"
      })
      |> html_response(200)

    assert page =~ "Recent Posts"
    assert page =~ Integer.to_string(matching_post.id)
    assert page =~ "green leaf"
    refute page =~ "other board"
  end

  test "browser board pages expose report queue and ban appeals management", %{conn: conn} do
    moderator = moderator_fixture(%{role: "admin"})
    board = board_fixture(%{uri: "tea", title: "Tea"})
    thread = thread_fixture(board, %{body: "Thread body"})

    report_conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "report_post_id" => Integer.to_string(thread.id),
        "reason" => "Spam",
        "json_response" => "1"
      })

    assert %{"report_id" => report_id} = json_response(report_conn, 200)

    {:ok, ban} =
      Eirinchan.Bans.create_ban(%{
        board_id: board.id,
        mod_user_id: moderator.id,
        ip_subnet: "198.51.100.9",
        reason: "Spam"
      })

    {:ok, appeal} = Eirinchan.Bans.create_appeal(ban.id, %{body: "Please review"})

    reports_page =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> get("/manage/boards/#{board.uri}/reports/browser")
      |> html_response(200)

    assert reports_page =~ "Reports for /#{board.uri}/"
    assert reports_page =~ "Spam"

    dismiss_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> delete("/manage/boards/#{board.uri}/reports/browser/#{report_id}")

    assert redirected_to(dismiss_conn) == "/manage/boards/#{board.uri}/reports/browser"

    appeals_page =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> get("/manage/boards/#{board.uri}/ban-appeals/browser")
      |> html_response(200)

    assert appeals_page =~ "Ban Appeals for /#{board.uri}/"
    assert appeals_page =~ "Please review"

    resolve_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> patch("/manage/boards/#{board.uri}/ban-appeals/browser/#{appeal.id}", %{
        "status" => "resolved",
        "resolution_note" => "Reviewed in browser"
      })

    assert redirected_to(resolve_conn) == "/manage/boards/#{board.uri}/ban-appeals/browser"
  end

  test "browser IP history page supports notes and delete-by-ip actions", %{conn: conn} do
    moderator = moderator_fixture(%{role: "admin"})
    board = board_fixture(%{uri: "tea", title: "Tea"})

    {:ok, thread, _meta} =
      Eirinchan.Posts.create_post(
        board,
        %{"body" => "green leaf", "subject" => "teaware", "post" => "New Topic"},
        config: Eirinchan.Runtime.Config.compose(nil, %{}, board.config_overrides),
        request: %{
          referer: "http://example.test/#{board.uri}/index.html",
          remote_ip: {198, 51, 100, 7}
        }
      )

    page =
      conn
      |> login_moderator(moderator)
      |> get("/manage/boards/#{board.uri}/ip/198.51.100.7/browser")
      |> html_response(200)

    assert page =~ "IP History: 198.51.100.7"
    assert page =~ "green leaf"

    note_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> post("/manage/boards/#{board.uri}/ip/198.51.100.7/browser/notes", %{
        "body" => "Watch this IP"
      })

    assert redirected_to(note_conn) == "/manage/boards/#{board.uri}/ip/198.51.100.7/browser"

    note = hd(Eirinchan.Moderation.list_ip_notes("198.51.100.7", board_id: board.id))

    update_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> patch("/manage/boards/#{board.uri}/ip/198.51.100.7/browser/notes/#{note.id}", %{
        "body" => "Updated note"
      })

    assert redirected_to(update_conn) == "/manage/boards/#{board.uri}/ip/198.51.100.7/browser"

    delete_posts_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> delete("/manage/boards/#{board.uri}/ip/198.51.100.7/browser/posts")

    assert redirected_to(delete_posts_conn) ==
             "/manage/boards/#{board.uri}/ip/198.51.100.7/browser"

    refute Eirinchan.Repo.get(Eirinchan.Posts.Post, thread.id)
  end

  test "browser moderation pages can move threads and replies", %{conn: conn} do
    moderator = moderator_fixture(%{role: "admin"})
    source_board = board_fixture(%{uri: "src"})
    target_board = board_fixture(%{uri: "dst"})
    source_thread = thread_fixture(source_board, %{body: "Thread to move"})
    _reply = reply_fixture(source_board, source_thread, %{body: "Thread reply"})
    reply_source_thread = thread_fixture(source_board, %{body: "Reply source"})
    target_thread = thread_fixture(target_board, %{body: "Reply target"})
    movable_reply = reply_fixture(source_board, reply_source_thread, %{body: "Reply to move"})

    move_thread_conn =
      conn
      |> login_moderator(moderator)
      |> patch("/manage/boards/#{source_board.uri}/threads/#{source_thread.id}/browser/move", %{
        "target_board_uri" => target_board.uri
      })

    assert redirected_to(move_thread_conn) == "/#{target_board.uri}/res/#{source_thread.id}.html"
    assert {:error, :not_found} = Eirinchan.Posts.get_thread(source_board, source_thread.id)

    assert {:ok, [_moved_thread, _moved_reply]} =
             Eirinchan.Posts.get_thread(target_board, source_thread.id)

    move_reply_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> patch("/manage/boards/#{source_board.uri}/posts/#{movable_reply.id}/browser/move", %{
        "target_board_uri" => target_board.uri,
        "target_thread_id" => Integer.to_string(target_thread.id)
      })

    assert redirected_to(move_reply_conn) == "/#{target_board.uri}/res/#{target_thread.id}.html"
    assert {:ok, [_thread]} = Eirinchan.Posts.get_thread(source_board, reply_source_thread.id)

    assert {:ok, [_target, moved_reply]} =
             Eirinchan.Posts.get_thread(target_board, target_thread.id)

    assert moved_reply.id == movable_reply.id
  end
end
