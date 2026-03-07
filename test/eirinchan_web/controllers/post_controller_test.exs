defmodule EirinchanWeb.PostControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "classic posting redirects OP creation to the thread page", %{conn: conn} do
    board = board_fixture(%{title: "Technology"})

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "name" => "anon",
        "subject" => "launch",
        "body" => "first post",
        "post" => "New Topic"
      })

    assert redirected_to(conn) == "/#{board.uri}"

    conn =
      conn
      |> recycle()
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "name" => "anon",
        "email" => "noko",
        "subject" => "launch",
        "body" => "second post",
        "post" => "New Topic"
      })

    thread_path = redirected_to(conn) |> String.split("#") |> hd()
    thread_page = conn |> recycle() |> get(thread_path) |> html_response(200)

    assert redirected_to(conn) =~ ~r|/#{board.uri}/res/\d+\.html|
    assert thread_page =~ "second post"
    assert thread_page =~ "launch"
  end

  test "json posting returns reply metadata", %{conn: conn} do
    board = board_fixture(%{title: "Technology"})
    thread = thread_fixture(board, %{body: "thread body", subject: "thread subject"})

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "thread" => Integer.to_string(thread.id),
        "email" => "noko",
        "body" => "reply body",
        "json_response" => "1",
        "post" => "New Reply"
      })

    thread_id = thread.id

    assert %{"id" => id, "thread_id" => ^thread_id, "redirect" => redirect, "noko" => true} =
             json_response(conn, 200)

    assert redirect == "/#{board.uri}/res/#{thread.id}.html#p#{id}"
  end

  test "noko redirects use canonical slug thread paths when slugify is enabled", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{slugify: true}})

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "email" => "noko",
        "subject" => "Slug redirect subject",
        "body" => "first post",
        "post" => "New Topic"
      })

    thread_path = redirected_to(conn)
    assert thread_path =~ "-slug-redirect-subject.html"
    assert conn |> recycle() |> get(thread_path) |> html_response(200) =~ "first post"
  end

  test "posting rejects replies to unknown threads", %{conn: conn} do
    board = board_fixture(%{title: "Technology"})

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "thread" => "999999",
        "body" => "reply body",
        "json_response" => "1",
        "post" => "New Reply"
      })

    assert %{"error" => "Thread not found"} = json_response(conn, 404)
  end

  test "posting rejects invalid referers and locked boards", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{board_locked: true}})

    locked_response =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "body" => "first post",
        "json_response" => "1",
        "post" => "New Topic"
      })

    assert %{"error" => "Board is locked."} = json_response(locked_response, 403)

    open_board = board_fixture()

    bad_referer =
      conn
      |> recycle()
      |> put_req_header("referer", "http://invalid.example/nope")
      |> post(~p"/#{open_board.uri}/post", %{
        "body" => "first post",
        "json_response" => "1",
        "post" => "New Topic"
      })

    assert %{"error" => "Invalid referer."} = json_response(bad_referer, 403)
  end

  test "report branch creates a report and returns thread redirect metadata", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{slugify: true}})
    thread = thread_fixture(board, %{subject: "Reported subject", body: "Thread body"})

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "report_post_id" => Integer.to_string(thread.id),
        "reason" => "Spam thread",
        "json_response" => "1"
      })

    assert %{"report_id" => _id, "redirect" => redirect, "status" => "ok"} =
             json_response(conn, 200)

    assert redirect =~ "/#{board.uri}/res/#{thread.id}-reported-subject.html"
  end

  test "report branch rejects unknown posts", %{conn: conn} do
    board = board_fixture()

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "report_post_id" => "999999",
        "reason" => "Spam thread",
        "json_response" => "1"
      })

    assert %{"error" => "Post not found"} = json_response(conn, 404)
  end

  test "delete branch removes replies and returns thread redirect metadata", %{conn: conn} do
    board = board_fixture(%{config_overrides: %{slugify: true}})

    thread =
      thread_fixture(board, %{subject: "Delete target", body: "Thread body", password: "threadpw"})

    reply_conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "thread" => Integer.to_string(thread.id),
        "body" => "Reply body",
        "password" => "replypw",
        "json_response" => "1",
        "post" => "New Reply"
      })

    assert %{"id" => reply_id} = json_response(reply_conn, 200)

    delete_conn =
      conn
      |> recycle()
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "delete_post_id" => Integer.to_string(reply_id),
        "password" => "replypw",
        "json_response" => "1"
      })

    assert %{
             "deleted_post_id" => ^reply_id,
             "thread_deleted" => false,
             "redirect" => redirect
           } = json_response(delete_conn, 200)

    assert redirect =~ "/#{board.uri}/res/#{thread.id}-delete-target.html"
  end

  test "delete branch removes threads and redirects to the board", %{conn: conn} do
    board = board_fixture()

    thread =
      thread_fixture(board, %{subject: "Delete thread", body: "Thread body", password: "threadpw"})

    delete_conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "delete_post_id" => Integer.to_string(thread.id),
        "password" => "threadpw",
        "json_response" => "1"
      })

    assert %{
             "deleted_post_id" => deleted_post_id,
             "thread_deleted" => true,
             "redirect" => redirect
           } = json_response(delete_conn, 200)

    assert deleted_post_id == thread.id
    assert redirect == "/#{board.uri}"
  end

  test "delete branch rejects incorrect passwords", %{conn: conn} do
    board = board_fixture()
    thread = thread_fixture(board, %{password: "threadpw"})

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post("/#{board.uri}/post", %{
        "delete_post_id" => Integer.to_string(thread.id),
        "password" => "wrong",
        "json_response" => "1"
      })

    assert %{"error" => "Incorrect password."} = json_response(conn, 403)
  end
end
