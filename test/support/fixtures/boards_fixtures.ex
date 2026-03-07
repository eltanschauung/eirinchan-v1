defmodule Eirinchan.BoardsFixtures do
  alias Eirinchan.Boards

  def board_fixture(attrs \\ %{}) do
    {:ok, board} =
      attrs
      |> Enum.into(%{
        uri: "test#{System.unique_integer([:positive])}",
        title: "Test Board",
        subtitle: "Fixture subtitle",
        config_overrides: %{}
      })
      |> Boards.create_board()

    board
  end
end
