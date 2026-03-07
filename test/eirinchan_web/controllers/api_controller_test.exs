defmodule EirinchanWeb.ApiControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "board api endpoints expose page, catalog, threads, and thread json", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{threads_per_page: 1, threads_preview: 1}})
    thread = thread_fixture(board, %{body: "Thread body", subject: "Thread subject"})

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
      "body" => "Second thread body",
      "subject" => "Second thread",
      "post" => "New Topic"
    })

    page_json =
      conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> get("/api/#{board.uri}/pages/0")
      |> json_response(200)

    catalog_json =
      conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> get("/api/#{board.uri}/catalog.json")
      |> json_response(200)

    threads_json =
      conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> get("/api/#{board.uri}/threads.json")
      |> json_response(200)

    thread_json =
      conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> get("/api/#{board.uri}/res/#{thread.id}")
      |> json_response(200)

    boards_json =
      conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> get("/api/boards.json")
      |> json_response(200)

    assert length(page_json["threads"]) == 1
    assert length(catalog_json) == 2
    assert Enum.all?(threads_json, &Map.has_key?(&1, "threads"))
    assert [op | replies] = thread_json["posts"]
    assert op["resto"] == 0
    assert length(replies) == 1

    assert Enum.any?(
             boards_json["boards"],
             &(&1["board"] == board.uri and &1["title"] == board.title)
           )
  end

  test "thread api exposes moderation state flags on OP posts", %{conn: conn} do
    board = board_fixture()
    thread = thread_fixture(board)

    conn =
      conn
      |> login_moderator(moderator_fixture())
      |> put_req_header("accept", "application/json")
      |> patch("/manage/boards/#{board.uri}/threads/#{thread.id}", %{
        "sticky" => "true",
        "locked" => "true",
        "cycle" => "true",
        "sage" => "true"
      })

    assert %{"data" => %{"sticky" => true}} = json_response(conn, 200)

    thread_json =
      conn
      |> recycle()
      |> put_req_header("accept", "application/json")
      |> get("/api/#{board.uri}/res/#{thread.id}")
      |> json_response(200)

    assert [op | _] = thread_json["posts"]
    assert op["sticky"] == 1
    assert op["closed"] == 1
    assert op["cyclical"] == 1
    assert op["bumplimit"] == 1
  end
end
