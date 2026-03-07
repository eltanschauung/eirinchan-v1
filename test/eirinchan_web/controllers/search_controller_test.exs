defmodule EirinchanWeb.SearchControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "public search returns matching posts and respects board filters", %{conn: conn} do
    board = board_fixture(%{uri: "tea#{System.unique_integer([:positive])}", title: "Tea"})

    other_board =
      board_fixture(%{uri: "meta#{System.unique_integer([:positive])}", title: "Meta"})

    {:ok, thread, _meta} =
      Eirinchan.Posts.create_post(
        board,
        %{"body" => "green tea leaf", "subject" => "tea", "post" => "New Topic"},
        config: Eirinchan.Runtime.Config.compose(nil, %{}, board.config_overrides),
        request: %{referer: "http://example.test/#{board.uri}/index.html"}
      )

    {:ok, _other_thread, _meta} =
      Eirinchan.Posts.create_post(
        other_board,
        %{"body" => "meta tea", "subject" => "meta", "post" => "New Topic"},
        config: Eirinchan.Runtime.Config.compose(nil, %{}, other_board.config_overrides),
        request: %{referer: "http://example.test/#{other_board.uri}/index.html"}
      )

    page =
      conn
      |> get("/search", %{"q" => "leaf", "board" => board.uri})
      |> html_response(200)

    assert page =~ "Search"
    assert page =~ "green tea leaf"
    assert page =~ "/#{board.uri}/res/#{thread.id}.html"
    refute page =~ "meta tea"
  end

  test "public search logs queries", %{conn: conn} do
    board =
      board_fixture(%{
        uri: "tea#{System.unique_integer([:positive])}",
        config_overrides: %{search_query_limit_window: 60, search_query_limit_count: 1}
      })

    conn = %{conn | remote_ip: {198, 51, 100, 99}}

    first_page =
      conn
      |> get("/search", %{"q" => "tripcode", "board" => board.uri})
      |> html_response(200)

    assert first_page =~ "No results."

    assert Enum.any?(
             Eirinchan.Antispam.list_search_queries("198.51.100.99", repo: Eirinchan.Repo),
             &(&1.query == "tripcode" and &1.board_id == board.id)
           )
  end

  test "public search supports id, thread, subject, and name filters", %{conn: conn} do
    board = board_fixture(%{uri: "search#{System.unique_integer([:positive])}", title: "Search"})

    {:ok, thread, _meta} =
      Eirinchan.Posts.create_post(
        board,
        %{
          "name" => "Alice",
          "subject" => "Tea topic",
          "body" => "green leaf",
          "post" => "New Topic"
        },
        config: Eirinchan.Runtime.Config.compose(nil, %{}, board.config_overrides),
        request: %{referer: "http://example.test/#{board.uri}/index.html"}
      )

    {:ok, reply, _meta} =
      Eirinchan.Posts.create_post(
        board,
        %{
          "thread" => Integer.to_string(thread.id),
          "name" => "Bob",
          "subject" => "Reply subject",
          "body" => "reply body",
          "post" => "New Reply"
        },
        config: Eirinchan.Runtime.Config.compose(nil, %{}, board.config_overrides),
        request: %{referer: "http://example.test/#{board.uri}/index.html"}
      )

    assert get(conn, "/search", %{"q" => "id:#{reply.id}", "board" => board.uri})
           |> html_response(200) =~ "reply body"

    assert get(conn, "/search", %{"q" => "thread:#{thread.id}", "board" => board.uri})
           |> html_response(200) =~ "reply body"

    assert get(conn, "/search", %{"q" => "subject:Tea", "board" => board.uri})
           |> html_response(200) =~ "green leaf"

    assert get(conn, "/search", %{"q" => "name:Alice", "board" => board.uri})
           |> html_response(200) =~ "green leaf"
  end
end
