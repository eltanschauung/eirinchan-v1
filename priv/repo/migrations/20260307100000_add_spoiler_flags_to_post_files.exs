defmodule Eirinchan.Repo.Migrations.AddSpoilerFlagsToPostFiles do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :spoiler, :boolean, default: false, null: false
    end

    alter table(:post_files) do
      add :spoiler, :boolean, default: false, null: false
    end
  end
end
