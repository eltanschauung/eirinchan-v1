defmodule Eirinchan.Repo.Migrations.CreateModUsers do
  use Ecto.Migration

  def change do
    create table(:mod_users) do
      add :username, :string, null: false
      add :password_hash, :string, null: false
      add :password_salt, :string, null: false
      add :role, :string, null: false, default: "admin"
      add :last_login_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:mod_users, [:username])
  end
end
