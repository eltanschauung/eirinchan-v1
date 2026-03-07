defmodule Eirinchan.Repo.Migrations.CreateModMessages do
  use Ecto.Migration

  def change do
    create table(:mod_messages) do
      add :subject, :string
      add :body, :text, null: false
      add :read_at, :utc_datetime_usec
      add :sender_id, references(:mod_users, on_delete: :delete_all), null: false
      add :recipient_id, references(:mod_users, on_delete: :delete_all), null: false
      add :reply_to_id, references(:mod_messages, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:mod_messages, [:recipient_id, :inserted_at])
    create index(:mod_messages, [:sender_id, :inserted_at])
    create index(:mod_messages, [:reply_to_id])
  end
end
