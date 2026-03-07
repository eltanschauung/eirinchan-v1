defmodule Eirinchan.BoardsCrudTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Boards

  test "create_board normalizes uri and persists overrides" do
    assert {:ok, board} =
             Boards.create_board(%{
               uri: "/tech/",
               title: "Technology",
               subtitle: "Wired",
               config_overrides: %{force_body: true}
             })

    assert board.uri == "tech"
    assert board.title == "Technology"
    assert board.config_overrides == %{force_body: true}
  end

  test "update_board updates persisted metadata" do
    board = board_fixture(%{title: "Meta"})

    assert {:ok, board} = Boards.update_board(board, %{title: "Meta Updated"})
    assert board.title == "Meta Updated"
  end

  test "open_board uses the repo-backed store by default" do
    board = board_fixture(%{title: "Technology", config_overrides: %{file_index: "home.html"}})

    assert {:ok, context} = Boards.open_board(board.uri, request_host: "example.test")
    assert context.board.uri == board.uri
    assert context.config.file_index == "home.html"
  end
end
