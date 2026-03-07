defmodule Eirinchan.PostsTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Posts

  test "create_post creates an OP when no thread is supplied" do
    board = board_fixture()

    assert {:ok, thread} =
             Posts.create_post(board, %{
               "name" => " anon ",
               "subject" => " launch ",
               "body" => "  first post  "
             })

    assert thread.thread_id == nil
    assert thread.name == "anon"
    assert thread.subject == "launch"
    assert thread.body == "first post"
  end

  test "create_post creates a reply when a valid thread is supplied" do
    board = board_fixture()
    thread = thread_fixture(board)

    assert {:ok, reply} =
             Posts.create_post(board, %{
               "thread" => Integer.to_string(thread.id),
               "body" => "reply body"
             })

    assert reply.thread_id == thread.id
  end

  test "create_post rejects replies to missing threads" do
    board = board_fixture()

    assert {:error, :thread_not_found} =
             Posts.create_post(board, %{"thread" => "999999", "body" => "reply body"})
  end
end
