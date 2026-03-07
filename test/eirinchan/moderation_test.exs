defmodule Eirinchan.ModerationTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Moderation

  test "create_user stores a hashed password and authenticate verifies it" do
    assert {:ok, moderator} =
             Moderation.create_user(%{
               username: "admin",
               password: "secret123",
               role: "admin"
             })

    assert moderator.password_hash
    assert moderator.password_salt
    refute moderator.password_hash == "secret123"

    assert {:ok, authenticated} = Moderation.authenticate("admin", "secret123")
    assert authenticated.id == moderator.id
    assert {:error, :invalid_credentials} = Moderation.authenticate("admin", "wrong")
  end

  test "board access is grant-based for non-admin moderators" do
    board = board_fixture()
    other_board = board_fixture()
    moderator = moderator_fixture(%{role: "mod"})
    admin = moderator_fixture(%{role: "admin"})

    refute Moderation.board_access?(moderator, board)
    assert Moderation.board_access?(admin, board)

    assert {:ok, _access} = Moderation.grant_board_access(moderator, board)

    assert Moderation.board_access?(moderator, board)
    refute Moderation.board_access?(moderator, other_board)
    assert Enum.map(Moderation.list_accessible_boards(moderator), & &1.id) == [board.id]
  end
end
