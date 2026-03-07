defmodule Eirinchan.Repo.Migrations.CreateAnnouncementEntries do
  use Ecto.Migration

  def change do
    create table(:announcement_entries) do
      add :title, :string, null: false
      add :body, :text, null: false
      add :mod_user_id, references(:mod_users, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:announcement_entries, [:updated_at])
  end
end
