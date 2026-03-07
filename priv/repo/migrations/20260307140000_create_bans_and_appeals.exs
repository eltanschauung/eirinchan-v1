defmodule Eirinchan.Repo.Migrations.CreateBansAndAppeals do
  use Ecto.Migration

  def change do
    create table(:bans) do
      add :board_id, references(:boards, on_delete: :delete_all)
      add :mod_user_id, references(:mod_users, on_delete: :nilify_all)
      add :ip_subnet, :string, null: false
      add :reason, :text
      add :expires_at, :utc_datetime_usec
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:bans, [:board_id])
    create index(:bans, [:ip_subnet])
    create index(:bans, [:active])

    create table(:ban_appeals) do
      add :ban_id, references(:bans, on_delete: :delete_all), null: false
      add :body, :text, null: false
      add :status, :string, default: "open", null: false
      add :resolution_note, :text
      add :resolved_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:ban_appeals, [:ban_id])
    create index(:ban_appeals, [:status])
  end
end
