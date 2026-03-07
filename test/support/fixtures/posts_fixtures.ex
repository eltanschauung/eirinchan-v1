defmodule Eirinchan.PostsFixtures do
  alias Eirinchan.BoardsFixtures
  alias Eirinchan.Posts

  def thread_fixture(board \\ nil, attrs \\ %{}) do
    board = board || BoardsFixtures.board_fixture()

    {:ok, thread, _meta} =
      board
      |> Posts.create_post(
        attrs
        |> Enum.into(%{body: "Opening post body", subject: "Opening subject", post: "New Topic"}),
        config: Eirinchan.Runtime.Config.compose(nil, %{}, board.config_overrides),
        request: %{referer: "http://example.test/#{board.uri}/index.html"}
      )

    thread
  end
end
