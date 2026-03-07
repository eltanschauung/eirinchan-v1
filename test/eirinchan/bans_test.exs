defmodule Eirinchan.BansTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Bans

  test "creates and lists bans" do
    board = board_fixture()
    moderator = moderator_fixture()

    assert {:ok, ban} =
             Bans.create_ban(%{
               board_id: board.id,
               mod_user_id: moderator.id,
               ip_subnet: "203.0.113.4",
               reason: "Spam"
             })

    assert [%{id: ban_id, ip_subnet: "203.0.113.4", reason: "Spam"}] =
             Bans.list_bans(board_id: board.id)

    assert ban_id == ban.id
  end

  test "creates ban appeals for existing bans" do
    assert {:ok, ban} = Bans.create_ban(%{ip_subnet: "203.0.113.4", reason: "Spam"})
    assert {:ok, appeal} = Bans.create_appeal(ban.id, %{body: "Please review"})

    assert [%{id: appeal_id, body: "Please review", status: "open"}] = Bans.list_appeals()
    assert appeal_id == appeal.id
  end
end
