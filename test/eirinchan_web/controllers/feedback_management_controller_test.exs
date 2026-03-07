defmodule EirinchanWeb.FeedbackManagementControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "feedback queue lists entries, marks read, adds notes, and deletes", %{conn: conn} do
    conn =
      conn
      |> post("/feedback", %{"body" => "Needs review", "json_response" => "1"})

    assert %{"feedback_id" => feedback_id} = json_response(conn, 200)

    queue_conn = put_req_header(recycle(conn), "accept", "application/json")

    assert %{"data" => [%{"id" => ^feedback_id, "body" => "Needs review", "read_at" => nil}]} =
             queue_conn
             |> get("/manage/feedback")
             |> json_response(200)

    assert %{"data" => %{"id" => ^feedback_id, "read_at" => read_at}} =
             queue_conn
             |> recycle()
             |> put_req_header("accept", "application/json")
             |> patch("/manage/feedback/#{feedback_id}/read", %{})
             |> json_response(200)

    assert read_at

    assert %{"data" => %{"comments" => [%{"body" => "Admin note"}]}} =
             queue_conn
             |> recycle()
             |> put_req_header("accept", "application/json")
             |> post("/manage/feedback/#{feedback_id}/comments", %{"body" => "Admin note"})
             |> json_response(200)

    assert response(
             queue_conn
             |> recycle()
             |> put_req_header("accept", "application/json")
             |> delete("/manage/feedback/#{feedback_id}"),
             204
           )

    assert %{"data" => []} =
             queue_conn
             |> recycle()
             |> put_req_header("accept", "application/json")
             |> get("/manage/feedback")
             |> json_response(200)
  end
end
