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
end
