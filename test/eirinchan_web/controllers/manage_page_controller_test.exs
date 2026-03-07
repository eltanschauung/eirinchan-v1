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
end
