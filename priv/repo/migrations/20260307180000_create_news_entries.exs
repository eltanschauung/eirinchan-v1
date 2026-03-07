defmodule Eirinchan.Repo.Migrations.CreateNewsEntries do
  use Ecto.Migration

  def change do
    create table(:news_entries) do
      add :title, :string, null: false
      add :body, :text, null: false
      add :mod_user_id, references(:mod_users, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:news_entries, [:inserted_at])
    create index(:news_entries, [:mod_user_id])
  end
end
