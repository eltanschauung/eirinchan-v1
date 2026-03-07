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

  test "create_post rejects replies to locked threads" do
    board = board_fixture()
    thread = thread_fixture(board)

    Repo.update_all(
      from(post in Eirinchan.Posts.Post, where: post.id == ^thread.id),
      set: [locked: true]
    )

    assert {:error, :thread_locked} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )
  end

  test "reply bumping reorders threads unless the reply is sage" do
    board = board_fixture()
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, older_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Older", "subject" => "Older", "post" => "New Topic"},
               config: config,
               request: request
             )

    Process.sleep(1000)

    assert {:ok, newer_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Newer", "subject" => "Newer", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(older_thread.id),
                 "body" => "Bumping reply",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, page_after_bump} = Posts.list_threads_page(board, 1, config: config)
    assert hd(page_after_bump.threads).thread.id == older_thread.id

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(newer_thread.id),
                 "body" => "Sage reply",
                 "email" => "sage",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, page_after_sage} = Posts.list_threads_page(board, 1, config: config)
    assert hd(page_after_sage.threads).thread.id == older_thread.id
  end

  test "find_thread_page tracks bump ordering and slug thread ids" do
    board = board_fixture(%{config_overrides: %{threads_per_page: 1, slugify: true}})
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, older_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Older body", "subject" => "Older subject", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, newer_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Newer body", "subject" => "Newer subject", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(older_thread.id),
                 "body" => "Bumping reply",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, 1} = Posts.find_thread_page(board, older_thread.id, config: config)

    assert {:ok, 2} =
             Posts.find_thread_page(board, "#{newer_thread.id}-newer-subject.html", config: config)

    assert {:ok, [thread | _]} =
             Posts.get_thread(board, "#{older_thread.id}-older-subject.html", config: config)

    assert thread.id == older_thread.id
  end

  test "list_threads_page returns previews, omitted counts, and page metadata" do
    board = board_fixture(%{config_overrides: %{threads_per_page: 1, threads_preview: 1}})
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, older_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Older body", "subject" => "Older", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(older_thread.id),
                 "body" => "Reply one",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(older_thread.id),
                 "body" => "Reply two",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, _newer_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Newer body", "subject" => "Newer", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, first_page} = Posts.list_threads_page(board, 1, config: config)
    assert first_page.page == 1
    assert first_page.total_pages == 2
    assert Enum.map(first_page.pages, & &1.num) == [1, 2]
    assert hd(first_page.threads).thread.subject == "Newer"

    assert {:ok, second_page} = Posts.list_threads_page(board, 2, config: config)
    summary = hd(second_page.threads)
    assert summary.thread.id == older_thread.id
    assert summary.reply_count == 2
    assert summary.omitted_posts == 1
    assert Enum.map(summary.replies, & &1.body) == ["Reply two"]
  end
end
