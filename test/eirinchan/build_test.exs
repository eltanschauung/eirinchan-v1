defmodule Eirinchan.BuildTest do
  use Eirinchan.DataCase, async: false

  alias Eirinchan.Build
  alias Eirinchan.Posts
  alias Eirinchan.Runtime.Config

  test "posting rebuilds paginated board, thread, and api files" do
    File.rm_rf!(Build.board_root())

    board =
      board_fixture(%{
        config_overrides: %{threads_per_page: 1, threads_preview: 1, api: %{enabled: true}}
      })

    config = Config.compose(nil, %{}, board.config_overrides, request_host: "example.test")
    request = %{referer: "http://example.test/#{board.uri}/index.html"}

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening post body",
                 "subject" => "Opening subject",
                 "post" => config.button_newtopic
               },
               config: config,
               request: request
             )

    assert {:ok, second_thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Second thread body",
                 "subject" => "Second thread subject",
                 "post" => config.button_newtopic
               },
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "post" => config.button_reply
               },
               config: config,
               request: request
             )

    board_dir = Path.join(Build.board_root(), board.uri)
    index_path = Path.join(board_dir, config.file_index)
    page_two_path = Path.join(board_dir, "2.html")
    thread_path = Path.join([board_dir, config.dir.res, "#{thread.id}.html"])
    thread_json_path = Path.join([board_dir, config.dir.res, "#{thread.id}.json"])
    page_zero_json_path = Path.join(board_dir, "0.json")
    catalog_json_path = Path.join(board_dir, "catalog.json")
    catalog_html_path = Path.join(board_dir, config.file_catalog)
    threads_json_path = Path.join(board_dir, "threads.json")

    assert File.read!(index_path) =~ "Opening subject"
    assert File.read!(index_path) =~ "Reply body"
    assert File.read!(index_path) =~ ~s(name="delete_post_id")
    assert File.read!(page_two_path) =~ "Second thread subject"
    assert File.read!(catalog_html_path) =~ "Second thread subject"
    assert File.read!(catalog_html_path) =~ ~s(name="delete_post_id")
    assert File.read!(thread_path) =~ "Reply body"
    assert File.read!(thread_path) =~ ~s(name="delete_post_id")
    assert Jason.decode!(File.read!(thread_json_path))["posts"] |> length() == 2

    assert Jason.decode!(File.read!(page_zero_json_path))["threads"]
           |> hd()
           |> Map.fetch!("posts")
           |> hd()
           |> Map.fetch!("no") == thread.id

    assert Jason.decode!(File.read!(Path.join(board_dir, "1.json")))["threads"]
           |> hd()
           |> Map.fetch!("posts")
           |> hd()
           |> Map.fetch!("no") == second_thread.id

    assert Jason.decode!(File.read!(catalog_json_path)) |> length() == 2
    assert Jason.decode!(File.read!(threads_json_path)) |> length() == 2
  end

  test "slugified threads build canonical and legacy html files" do
    File.rm_rf!(Build.board_root())

    board = board_fixture(%{config_overrides: %{slugify: true}})
    config = Config.compose(nil, %{}, board.config_overrides, request_host: "example.test")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "subject" => "Slug file subject",
                 "post" => config.button_newtopic
               },
               config: config,
               request: %{referer: "http://example.test/#{board.uri}/index.html"}
             )

    board_dir = Path.join(Build.board_root(), board.uri)
    canonical_path = Path.join([board_dir, config.dir.res, "#{thread.id}-slug-file-subject.html"])
    legacy_path = Path.join([board_dir, config.dir.res, "#{thread.id}.html"])

    assert File.read!(canonical_path) =~ "Opening body"
    assert File.read!(legacy_path) =~ "Opening body"
  end

  test "thread state updates rebuild static board and thread outputs" do
    File.rm_rf!(Build.board_root())

    board = board_fixture()
    config = Config.compose(nil, %{}, board.config_overrides, request_host: "example.test")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "subject" => "Managed subject",
                 "post" => config.button_newtopic
               },
               config: config,
               request: %{referer: "http://example.test/#{board.uri}/index.html"}
             )

    assert {:ok, _updated_thread} =
             Posts.update_thread_state(
               board,
               thread.id,
               %{"sticky" => "true", "locked" => "true"},
               config: config
             )

    board_dir = Path.join(Build.board_root(), board.uri)
    index_path = Path.join(board_dir, config.file_index)
    thread_path = Path.join([board_dir, config.dir.res, "#{thread.id}.html"])

    assert File.read!(index_path) =~ "[Sticky]"
    assert File.read!(index_path) =~ "[Locked]"
    assert File.read!(thread_path) =~ "[Sticky]"
    assert File.read!(thread_path) =~ "[Locked]"
  end

  test "deleting posts updates static thread and board outputs" do
    File.rm_rf!(Build.board_root())

    board = board_fixture(%{config_overrides: %{slugify: true}})
    config = Config.compose(nil, %{}, board.config_overrides, request_host: "example.test")
    request = %{referer: "http://example.test/#{board.uri}/index.html"}

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "subject" => "Delete subject",
                 "password" => "threadpw",
                 "post" => config.button_newtopic
               },
               config: config,
               request: request
             )

    assert {:ok, reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "password" => "replypw",
                 "post" => config.button_reply
               },
               config: config,
               request: request
             )

    board_dir = Path.join(Build.board_root(), board.uri)
    thread_path = Path.join([board_dir, config.dir.res, "#{thread.id}.html"])

    canonical_thread_path =
      Path.join([board_dir, config.dir.res, "#{thread.id}-delete-subject.html"])

    assert File.read!(thread_path) =~ "Reply body"

    assert {:ok, %{thread_deleted: false}} =
             Posts.delete_post(board, reply.id, "replypw", config: config)

    refute File.read!(thread_path) =~ "Reply body"

    assert {:ok, %{thread_deleted: true}} =
             Posts.delete_post(board, thread.id, "threadpw", config: config)

    refute File.exists?(thread_path)
    refute File.exists?(canonical_thread_path)
  end
end
