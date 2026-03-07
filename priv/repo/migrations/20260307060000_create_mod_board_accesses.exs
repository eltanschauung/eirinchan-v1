defmodule Eirinchan.Repo.Migrations.CreateModBoardAccesses do
  use Ecto.Migration

  def change do
    create table(:mod_board_accesses) do
      add :mod_user_id, references(:mod_users, on_delete: :delete_all), null: false
      add :board_id, references(:boards, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:mod_board_accesses, [:mod_user_id, :board_id])
    create index(:mod_board_accesses, [:board_id])
  end
end
