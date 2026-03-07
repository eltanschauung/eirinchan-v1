defmodule Eirinchan.Repo.Migrations.AddThreadStateFieldsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :bump_at, :utc_datetime_usec
      add :sticky, :boolean, null: false, default: false
      add :locked, :boolean, null: false, default: false
      add :cycle, :boolean, null: false, default: false
      add :sage, :boolean, null: false, default: false
      add :slug, :string
    end

    execute(
      "UPDATE posts SET bump_at = inserted_at WHERE thread_id IS NULL AND bump_at IS NULL",
      "UPDATE posts SET bump_at = NULL"
    )

    create index(:posts, [:board_id, :sticky, :bump_at])
  end
end
