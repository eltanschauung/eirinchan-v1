defmodule Eirinchan.BuildTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Build
  alias Eirinchan.Posts
  alias Eirinchan.Runtime.Config

  test "posting rebuilds board index and thread files" do
    board = board_fixture()
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
    thread_path = Path.join([board_dir, config.dir.res, "#{thread.id}.html"])

    assert File.read!(index_path) =~ "Opening subject"
    assert File.read!(thread_path) =~ "Reply body"
  end
end
