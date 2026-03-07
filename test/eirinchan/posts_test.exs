defmodule Eirinchan.PostsTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Posts
  alias Eirinchan.Runtime.Config

  defp post_config(board_overrides) do
    Config.compose(nil, %{}, board_overrides, request_host: "example.test")
  end

  defp post_request(board_uri) do
    %{referer: "http://example.test/#{board_uri}/index.html"}
  end

  test "create_post creates an OP when no thread is supplied" do
    board = board_fixture()

    assert {:ok, thread, %{noko: false}} =
             Posts.create_post(
               board,
               %{
                 "name" => " anon ",
                 "subject" => " launch ",
                 "body" => "  first post  ",
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert thread.thread_id == nil
    assert thread.name == "anon"
    assert thread.subject == "launch"
    assert thread.body == "first post"
  end

  test "create_post creates a reply when a valid thread is supplied" do
    board = board_fixture()
    thread = thread_fixture(board)

    assert {:ok, reply, %{noko: false}} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "reply body",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert reply.thread_id == thread.id
  end

  test "create_post rejects replies to missing threads" do
    board = board_fixture()

    assert {:error, :thread_not_found} =
             Posts.create_post(
               board,
               %{
                 "thread" => "999999",
                 "body" => "reply body",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )
  end

  test "create_post rejects an invalid referer" do
    board = board_fixture()

    assert {:error, :invalid_referer} =
             Posts.create_post(board, %{"body" => "first post", "post" => "New Topic"},
               config: post_config(board.config_overrides),
               request: %{referer: "http://bad.example/elsewhere"}
             )
  end

  test "create_post enforces board lock and body requirements from config" do
    board = board_fixture(%{config_overrides: %{board_locked: true, force_body_op: true}})

    assert {:error, :board_locked} =
             Posts.create_post(board, %{"body" => "first post", "post" => "New Topic"},
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    unlocked = %{board | config_overrides: %{force_body_op: true}}

    assert {:error, :body_required} =
             Posts.create_post(unlocked, %{"body" => "   ", "post" => "New Topic"},
               config: post_config(unlocked.config_overrides),
               request: post_request(board.uri)
             )
  end

  test "create_post enforces reply hard limits" do
    board = board_fixture(%{config_overrides: %{reply_hard_limit: 1}})
    thread = thread_fixture(board)

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "first reply",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert {:error, :reply_hard_limit} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "second reply",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )
  end
end
