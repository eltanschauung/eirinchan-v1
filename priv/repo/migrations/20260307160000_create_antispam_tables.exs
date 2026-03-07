defmodule Eirinchan.Repo.Migrations.CreateAntispamTables do
  use Ecto.Migration

  def change do
    create table(:flood_entries) do
      add :board_id, references(:boards, on_delete: :delete_all), null: false
      add :ip_subnet, :string, null: false
      add :body_hash, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:flood_entries, [:board_id, :ip_subnet, :inserted_at])
    create index(:flood_entries, [:board_id, :ip_subnet, :body_hash, :inserted_at])

    create table(:search_queries) do
      add :board_id, references(:boards, on_delete: :delete_all)
      add :ip_subnet, :string, null: false
      add :query, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:search_queries, [:ip_subnet, :query, :inserted_at])
    create index(:search_queries, [:board_id, :ip_subnet, :query, :inserted_at])
  end
end
