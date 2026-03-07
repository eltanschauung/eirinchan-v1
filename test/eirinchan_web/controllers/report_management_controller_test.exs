defmodule EirinchanWeb.ReportManagementControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "lists and dismisses board reports", %{conn: conn} do
    board = board_fixture()
    thread = thread_fixture(board, %{body: "Thread body", subject: "Thread subject"})
    moderator = moderator_fixture()

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "report_post_id" => Integer.to_string(thread.id),
        "reason" => "Off topic",
        "json_response" => "1"
      })

    assert %{"report_id" => report_id} = json_response(conn, 200)

    conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> put_req_header("accept", "application/json")

    assert %{"data" => [%{"id" => ^report_id, "post_id" => post_id, "reason" => "Off topic"}]} =
             conn
             |> get("/manage/boards/#{board.uri}/reports")
             |> json_response(200)

    assert post_id == thread.id

    assert response(
             conn
             |> recycle()
             |> login_moderator(moderator)
             |> put_req_header("accept", "application/json")
             |> delete("/manage/boards/#{board.uri}/reports/#{report_id}"),
             204
           )

    assert %{"data" => []} =
             conn
             |> recycle()
             |> login_moderator(moderator)
             |> put_req_header("accept", "application/json")
             |> get("/manage/boards/#{board.uri}/reports")
             |> json_response(200)
  end

  test "dismisses all open reports for a post", %{conn: conn} do
    board = board_fixture()
    thread = thread_fixture(board)
    moderator = moderator_fixture()

    first_report_conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "report_post_id" => Integer.to_string(thread.id),
        "reason" => "Off topic",
        "json_response" => "1"
      })

    assert %{"report_id" => _report_id} = json_response(first_report_conn, 200)

    second_report_conn =
      conn
      |> recycle()
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "report_post_id" => Integer.to_string(thread.id),
        "reason" => "Spam",
        "json_response" => "1"
      })

    assert %{"report_id" => _report_id} = json_response(second_report_conn, 200)

    assert response(
             conn
             |> recycle()
             |> login_moderator(moderator)
             |> put_req_header("accept", "application/json")
             |> delete("/manage/boards/#{board.uri}/reports/post/#{thread.id}"),
             204
           )

    assert %{"data" => []} =
             conn
             |> recycle()
             |> login_moderator(moderator)
             |> put_req_header("accept", "application/json")
             |> get("/manage/boards/#{board.uri}/reports")
             |> json_response(200)
  end
end
