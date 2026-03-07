defmodule EirinchanWeb.PostManagementControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "shows, edits, deletes files, spoilerizes, and deletes board posts", %{conn: conn} do
    board = board_fixture()
    moderator = moderator_fixture(%{role: "mod"}) |> grant_board_access_fixture(board)

    create_conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "body" => "Opening body",
        "files" => [
          upload_fixture("first.png", "first"),
          upload_fixture("second.gif", "second")
        ],
        "json_response" => "1",
        "post" => "New Topic"
      })

    assert %{"id" => thread_id} = json_response(create_conn, 200)

    show_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> put_req_header("accept", "application/json")
      |> get("/manage/boards/#{board.uri}/posts/#{thread_id}")

    assert %{
             "data" => %{
               "id" => ^thread_id,
               "body" => "Opening body",
               "file_path" => file_path,
               "extra_files" => [_extra]
             }
           } = json_response(show_conn, 200)

    assert is_binary(file_path)

    update_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> put_secure_manage_token()
      |> put_req_header("accept", "application/json")
      |> patch("/manage/boards/#{board.uri}/posts/#{thread_id}", %{
        "body" => "<strong>Updated</strong>",
        "raw_html" => "1"
      })

    assert %{
             "data" => %{
               "id" => ^thread_id,
               "raw_html" => true,
               "body" => "<strong>Updated</strong>"
             }
           } = json_response(update_conn, 200)

    spoiler_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> put_secure_manage_token()
      |> put_req_header("accept", "application/json")
      |> patch("/manage/boards/#{board.uri}/posts/#{thread_id}/spoiler", %{})

    assert %{
             "data" => %{
               "id" => ^thread_id,
               "spoiler" => true,
               "extra_files" => [%{"spoiler" => true}]
             }
           } = json_response(spoiler_conn, 200)

    delete_file_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> put_secure_manage_token()
      |> put_req_header("accept", "application/json")
      |> delete("/manage/boards/#{board.uri}/posts/#{thread_id}/file")

    assert %{"data" => %{"id" => ^thread_id, "file_path" => nil, "extra_files" => []}} =
             json_response(delete_file_conn, 200)

    delete_post_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> put_secure_manage_token()
      |> put_req_header("accept", "application/json")
      |> delete("/manage/boards/#{board.uri}/posts/#{thread_id}")

    assert %{"data" => %{"deleted_post_id" => ^thread_id, "thread_deleted" => true}} =
             json_response(delete_post_conn, 200)
  end

  test "post management routes reject moderators without access", %{conn: conn} do
    board = board_fixture()
    thread = thread_fixture(board)
    moderator = moderator_fixture(%{role: "mod"})

    conn =
      conn
      |> login_moderator(moderator)
      |> put_req_header("accept", "application/json")
      |> get("/manage/boards/#{board.uri}/posts/#{thread.id}")

    assert %{"error" => "forbidden"} = json_response(conn, 403)
  end
end
