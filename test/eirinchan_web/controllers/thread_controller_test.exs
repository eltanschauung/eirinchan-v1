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
end
