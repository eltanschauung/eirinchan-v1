defmodule Eirinchan.ModerationFixtures do
  alias Eirinchan.Moderation

  def moderator_fixture(attrs \\ %{}) do
    {:ok, moderator} =
      attrs
      |> Enum.into(%{
        username: "mod#{System.unique_integer([:positive])}",
        password: "secret123",
        role: "admin"
      })
      |> Moderation.create_user()

    moderator
  end
end
