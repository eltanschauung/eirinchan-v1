defmodule Eirinchan.PostsFixtures do
  alias Eirinchan.BoardsFixtures
  alias Eirinchan.Posts

  def thread_fixture(board \\ nil, attrs \\ %{}) do
    board = board || BoardsFixtures.board_fixture()

    {:ok, thread} =
      board
      |> Posts.create_post(
        attrs
        |> Enum.into(%{body: "Opening post body", subject: "Opening subject"})
      )

    thread
  end
end
