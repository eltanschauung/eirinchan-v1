defmodule Eirinchan.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :board_id, references(:boards, on_delete: :delete_all), null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :thread_id, references(:posts, on_delete: :delete_all), null: false
      add :reason, :text, null: false
      add :dismissed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:reports, [:board_id, :inserted_at])
    create index(:reports, [:board_id, :dismissed_at])

    create unique_index(:reports, [:post_id, :reason, :dismissed_at],
             name: :reports_post_reason_dismissed_unique_index
           )
  end
end
