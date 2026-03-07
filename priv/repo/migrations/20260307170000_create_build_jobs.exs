defmodule Eirinchan.Repo.Migrations.CreateBuildJobs do
  use Ecto.Migration

  def change do
    create table(:build_jobs) do
      add :board_id, references(:boards, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :thread_id, :bigint
      add :status, :string, null: false, default: "pending"
      add :finished_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:build_jobs, [:board_id, :status, :inserted_at])
  end
end
