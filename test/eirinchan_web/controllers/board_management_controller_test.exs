defmodule EirinchanWeb.BoardManagementControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "creates, updates, shows, and deletes boards over HTTP", %{conn: conn} do
    moderator = moderator_fixture()

    conn =
      conn
      |> login_moderator(moderator)
      |> put_req_header("accept", "application/json")

    conn =
      post(conn, ~p"/manage/boards", %{
        uri: "tech",
        title: "Technology",
        subtitle: "Wired",
        config_overrides: %{force_body: true}
      })

    assert %{
             "data" => %{
               "uri" => "tech",
               "title" => "Technology",
               "subtitle" => "Wired",
               "config_overrides" => %{"force_body" => true}
             }
           } = json_response(conn, 201)

    assert %{"data" => %{"uri" => "tech"}} =
             conn
             |> recycle()
             |> login_moderator(moderator)
             |> get(~p"/manage/boards/tech")
             |> json_response(200)

    assert %{"data" => %{"title" => "Technology+"}} =
             conn
             |> recycle()
             |> login_moderator(moderator)
             |> patch(~p"/manage/boards/tech", %{title: "Technology+"})
             |> json_response(200)

    assert response(
             conn
             |> recycle()
             |> login_moderator(moderator)
             |> delete(~p"/manage/boards/tech"),
             204
           )

    assert %{"error" => "not_found"} =
             conn
             |> recycle()
             |> login_moderator(moderator)
             |> get(~p"/manage/boards/tech")
             |> json_response(404)
  end

  test "board page loads through the DB-backed board context", %{conn: conn} do
    board = board_fixture(%{title: "Technology", subtitle: "Wired"})

    response =
      conn
      |> get(~p"/#{board.uri}")
      |> html_response(200)

    assert response =~ "/ #{board.uri} / - Technology"
    assert response =~ "Wired"
    assert response =~ "No threads yet."
  end

  test "board pages render previews, omitted counts, and pagination", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{threads_per_page: 1, threads_preview: 1}})
    thread = thread_fixture(board, %{body: "Older body", subject: "Older"})

    conn
    |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
    |> post(~p"/#{board.uri}/post", %{
      "thread" => Integer.to_string(thread.id),
      "body" => "Reply one",
      "post" => "New Reply"
    })

    conn
    |> recycle()
    |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
    |> post(~p"/#{board.uri}/post", %{
      "thread" => Integer.to_string(thread.id),
      "body" => "Reply two",
      "post" => "New Reply"
    })

    conn
    |> recycle()
    |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
    |> post(~p"/#{board.uri}/post", %{
      "body" => "Newer body",
      "subject" => "Newer",
      "post" => "New Topic"
    })

    first_page =
      conn
      |> recycle()
      |> get(~p"/#{board.uri}")
      |> html_response(200)

    second_page =
      conn
      |> recycle()
      |> get("/#{board.uri}/2.html")
      |> html_response(200)

    assert first_page =~ "Newer"
    assert first_page =~ "/#{board.uri}/2.html"
    assert first_page =~ ~s(name="delete_post_id")
    assert second_page =~ "Older"
    assert second_page =~ "1 posts"
    assert second_page =~ "Reply two"
    assert second_page =~ ~s(name="delete_post_id")
  end

  test "catalog page renders thread summaries across board pages", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{threads_per_page: 1}})

    conn
    |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
    |> post(~p"/#{board.uri}/post", %{
      "body" => "First body",
      "subject" => "First thread",
      "post" => "New Topic"
    })

    conn
    |> recycle()
    |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
    |> post(~p"/#{board.uri}/post", %{
      "body" => "Second body",
      "subject" => "Second thread",
      "post" => "New Topic"
    })

    catalog_page =
      conn
      |> recycle()
      |> get("/#{board.uri}/catalog.html")
      |> html_response(200)

    assert catalog_page =~ "Catalog"
    assert catalog_page =~ "First thread"
    assert catalog_page =~ "Second thread"
    assert catalog_page =~ ~s(name="delete_post_id")
  end

  test "board page respects field disable flags and single-file selector mode", %{conn: conn} do
    board =
      board_fixture(%{
        config_overrides: %{
          field_disable_name: true,
          field_disable_email: true,
          field_disable_subject: true,
          field_disable_password: true,
          max_images: 1
        }
      })

    page =
      conn
      |> get(~p"/#{board.uri}")
      |> html_response(200)

    refute page =~ ~s(name="name")
    refute page =~ ~s(name="email")
    refute page =~ ~s(name="subject")
    refute page =~ ~s(name="password" placeholder="Password")
    assert page =~ ~s(name="file")
    refute page =~ ~s(name="files[]")
    refute page =~ "multiple"
  end

  test "board page exposes multi-file selector when max_images is greater than one", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{max_images: 3}})

    page =
      conn
      |> get(~p"/#{board.uri}")
      |> html_response(200)

    assert page =~ ~s(name="files[]")
    assert page =~ "multiple"
  end

  test "board page renders user flag select with the configured default", %{conn: conn} do
    board =
      board_fixture(%{
        config_overrides: %{
          user_flag: true,
          default_user_flag: "spc",
          user_flags: %{"sau" => "Sauce", "spc" => "Space"}
        }
      })

    page =
      conn
      |> get(~p"/#{board.uri}")
      |> html_response(200)

    document = Floki.parse_document!(page)

    assert Floki.find(document, ~s(select[name="user_flag"])) != []
    assert Floki.find(document, ~s(option[value="spc"][selected])) != []
    assert page =~ "Sauce"
    assert page =~ "Space"
  end
end
