defmodule EirinchanWeb.ThreadControllerTest do
  use EirinchanWeb.ConnCase, async: true

  alias Eirinchan.Posts
  alias Eirinchan.Runtime.Config
  alias Eirinchan.ThreadPaths

  test "plain thread urls redirect to the canonical slug path", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{slugify: true}})
    config = Config.compose(nil, %{}, board.config_overrides, request_host: "www.example.com")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "subject" => "Thread slug test",
                 "body" => "Opening body",
                 "post" => "New Topic"
               },
               config: config,
               request: %{referer: "http://www.example.com/#{board.uri}/index.html"}
             )

    conn = get(conn, "/#{board.uri}/res/#{thread.id}.html")

    assert redirected_to(conn) == ThreadPaths.thread_path(board, thread, config)
  end

  test "canonical thread urls render with a return link to the current board page", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{slugify: true, threads_per_page: 1}})
    config = Config.compose(nil, %{}, board.config_overrides, request_host: "www.example.com")
    request = %{referer: "http://www.example.com/#{board.uri}/index.html"}

    assert {:ok, older_thread, _meta} =
             Posts.create_post(
               board,
               %{"subject" => "Older subject", "body" => "Older body", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, _newer_thread, _meta} =
             Posts.create_post(
               board,
               %{"subject" => "Newer subject", "body" => "Newer body", "post" => "New Topic"},
               config: config,
               request: request
             )

    thread_path = ThreadPaths.thread_path(board, older_thread, config)
    page = conn |> get(thread_path) |> html_response(200)

    assert page =~ ~s(href="/#{board.uri}/2.html")
    assert page =~ "Older body"
    assert page =~ ~s(name="delete_post_id")
  end

  test "thread reply form respects reply field toggles and multi-file selector mode", %{
    conn: conn
  } do
    board =
      board_fixture(%{
        config_overrides: %{
          field_disable_name: true,
          field_disable_email: true,
          field_disable_reply_subject: true,
          field_disable_password: true,
          max_images: 2
        }
      })

    thread = thread_fixture(board, %{body: "Thread body", subject: "Thread subject"})
    page = conn |> get("/#{board.uri}/res/#{thread.id}.html") |> html_response(200)
    document = Floki.parse_document!(page)

    reply_form =
      document
      |> Floki.find("form")
      |> Enum.find(fn form ->
        Floki.find(form, ~s(input[name="thread"][value="#{thread.id}"])) != []
      end)

    assert reply_form
    assert Floki.find(reply_form, ~s(input[name="name"])) == []
    assert Floki.find(reply_form, ~s(input[name="email"])) == []
    assert Floki.find(reply_form, ~s(input[name="subject"])) == []
    assert Floki.find(reply_form, ~s(input[name="password"])) == []
    assert Floki.find(reply_form, ~s(input[name="files[]"][multiple])) != []
  end

  test "thread pages render stored user flag labels", %{conn: conn} do
    board =
      board_fixture(%{
        config_overrides: %{user_flag: true, user_flags: %{"sau" => "Sauce", "spc" => "Space"}}
      })

    config = Config.compose(nil, %{}, board.config_overrides, request_host: "www.example.com")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "user_flag" => "sau",
                 "post" => "New Topic"
               },
               config: config,
               request: %{referer: "http://www.example.com/#{board.uri}/index.html"}
             )

    page = conn |> get("/#{board.uri}/res/#{thread.id}.html") |> html_response(200)

    assert page =~ "Flags: Sauce"
  end

  test "thread pages render stored OP tags", %{conn: conn} do
    board =
      board_fixture(%{
        config_overrides: %{allowed_tags: %{"A" => "Anime", "M" => "Music"}}
      })

    config = Config.compose(nil, %{}, board.config_overrides, request_host: "www.example.com")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "tag" => "A",
                 "post" => "New Topic"
               },
               config: config,
               request: %{referer: "http://www.example.com/#{board.uri}/index.html"}
             )

    page = conn |> get("/#{board.uri}/res/#{thread.id}.html") |> html_response(200)

    assert page =~ "Tag: Anime"
  end

  test "thread pages render moderator raw html and capcodes", %{conn: conn} do
    board = board_fixture()
    moderator = moderator_fixture(%{role: "admin"}) |> grant_board_access_fixture(board)
    config = Config.compose(nil, %{}, board.config_overrides, request_host: "www.example.com")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "<strong>mod notice</strong>",
                 "capcode" => "admin",
                 "raw" => "1",
                 "post" => "New Topic"
               },
               config: config,
               request: %{
                 referer: "http://www.example.com/#{board.uri}/index.html",
                 moderator: moderator
               }
             )

    page = conn |> get("/#{board.uri}/res/#{thread.id}.html") |> html_response(200)

    assert page =~ "<strong>mod notice</strong>"
    assert page =~ "Capcode: Admin"
  end

  test "thread pages render the boardlist", %{conn: conn} do
    board_fixture(%{uri: "meta", title: "Meta"})
    board = board_fixture()
    thread = thread_fixture(board)

    page = conn |> get("/#{board.uri}/res/#{thread.id}.html") |> html_response(200)

    assert page =~ "/ meta /"
    assert page =~ "/ #{board.uri} /"
  end

  test "thread pages render poster tripcodes", %{conn: conn} do
    board = board_fixture()
    config = Config.compose(nil, %{}, board.config_overrides, request_host: "www.example.com")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{"name" => "Anon#secret", "body" => "Opening body", "post" => "New Topic"},
               config: config,
               request: %{referer: "http://www.example.com/#{board.uri}/index.html"}
             )

    page = conn |> get("/#{board.uri}/res/#{thread.id}.html") |> html_response(200)

    assert page =~ thread.tripcode
  end
end
