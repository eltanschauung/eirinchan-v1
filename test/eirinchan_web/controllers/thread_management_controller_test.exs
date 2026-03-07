defmodule EirinchanWeb.ThreadManagementControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "shows and updates board-scoped thread state", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{threads_per_page: 1}})
    older_thread = thread_fixture(board, %{body: "Older body", subject: "Older"})
    _newer_thread = thread_fixture(board, %{body: "Newer body", subject: "Newer"})
    older_thread_id = older_thread.id

    conn = put_req_header(conn, "accept", "application/json")

    assert %{"data" => %{"id" => ^older_thread_id, "sticky" => false, "locked" => false}} =
             conn
             |> get("/manage/boards/#{board.uri}/threads/#{older_thread.id}")
             |> json_response(200)

    assert %{
             "data" => %{
               "id" => ^older_thread_id,
               "sticky" => true,
               "locked" => true,
               "cycle" => true,
               "sage" => true
             }
           } =
             conn
             |> recycle()
             |> patch("/manage/boards/#{board.uri}/threads/#{older_thread.id}", %{
               "sticky" => "true",
               "locked" => "true",
               "cycle" => "true",
               "sage" => "true"
             })
             |> json_response(200)

    first_page =
      conn
      |> recycle()
      |> put_req_header("accept", "text/html")
      |> get("/#{board.uri}")
      |> html_response(200)

    assert first_page =~ "Older"
    assert first_page =~ "[Sticky]"
    assert first_page =~ "[Locked]"
    assert first_page =~ "[Cyclical]"
    assert first_page =~ "[Bumplocked]"
  end

  test "locked thread state blocks posting replies after management update", %{conn: conn} do
    board = board_fixture()
    thread = thread_fixture(board)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> patch("/manage/boards/#{board.uri}/threads/#{thread.id}", %{"locked" => "true"})

    assert %{"data" => %{"locked" => true}} = json_response(conn, 200)

    locked_reply =
      conn
      |> recycle()
      |> put_req_header("accept", "text/html")
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "thread" => Integer.to_string(thread.id),
        "body" => "reply body",
        "json_response" => "1",
        "post" => "New Reply"
      })

    assert %{"error" => "Thread locked. You may not reply at this time."} =
             json_response(locked_reply, 403)
  end
end
