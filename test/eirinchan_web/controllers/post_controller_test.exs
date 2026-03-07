defmodule EirinchanWeb.PostControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "classic posting redirects OP creation to the thread page", %{conn: conn} do
    board = board_fixture(%{title: "Technology"})

    conn =
      post(conn, ~p"/#{board.uri}/post", %{
        "name" => "anon",
        "subject" => "launch",
        "body" => "first post"
      })

    assert redirected_to(conn) =~ ~r|/#{board.uri}/res/\d+\.html#p\d+|

    thread_path = redirected_to(conn) |> String.split("#") |> hd()
    thread_page = conn |> recycle() |> get(thread_path) |> html_response(200)

    assert thread_page =~ "first post"
    assert thread_page =~ "launch"
  end

  test "json posting returns reply metadata", %{conn: conn} do
    board = board_fixture(%{title: "Technology"})
    thread = thread_fixture(board, %{body: "thread body", subject: "thread subject"})

    conn =
      post(conn, ~p"/#{board.uri}/post", %{
        "thread" => Integer.to_string(thread.id),
        "body" => "reply body",
        "json_response" => "1"
      })

    thread_id = thread.id

    assert %{"id" => id, "thread_id" => ^thread_id, "redirect" => redirect} =
             json_response(conn, 200)

    assert redirect == "/#{board.uri}/res/#{thread.id}.html#p#{id}"
  end

  test "posting rejects replies to unknown threads", %{conn: conn} do
    board = board_fixture(%{title: "Technology"})

    conn =
      post(conn, ~p"/#{board.uri}/post", %{
        "thread" => "999999",
        "body" => "reply body",
        "json_response" => "1"
      })

    assert %{"error" => "Thread not found"} = json_response(conn, 404)
  end
end
