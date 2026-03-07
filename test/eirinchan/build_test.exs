defmodule Eirinchan.BuildTest do
  use Eirinchan.DataCase, async: true

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

    assert {:ok, _second_thread, _meta} =
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
    threads_json_path = Path.join(board_dir, "threads.json")

    assert File.read!(index_path) =~ "Second thread subject"
    assert File.read!(page_two_path) =~ "Opening subject"
    assert File.read!(thread_path) =~ "Reply body"
    assert Jason.decode!(File.read!(thread_json_path))["posts"] |> length() == 2
    assert Jason.decode!(File.read!(page_zero_json_path))["threads"] |> length() == 1
    assert Jason.decode!(File.read!(catalog_json_path)) |> length() == 2
    assert Jason.decode!(File.read!(threads_json_path)) |> length() == 2
  end
end
