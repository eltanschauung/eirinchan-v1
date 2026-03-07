defmodule Eirinchan.Repo.Migrations.AddPostIpsAndIpNotes do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :ip_subnet, :string
    end

    create index(:posts, [:ip_subnet])
    create index(:posts, [:board_id, :ip_subnet, :inserted_at])

    create table(:ip_notes) do
      add :ip_subnet, :string, null: false
      add :body, :text, null: false
      add :board_id, references(:boards, on_delete: :delete_all)
      add :mod_user_id, references(:mod_users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:ip_notes, [:ip_subnet, :inserted_at])
    create index(:ip_notes, [:board_id, :ip_subnet, :inserted_at])
  end
end
