defmodule Eirinchan.Repo.Migrations.CreateCitesAndNntpReferences do
  use Ecto.Migration

  def change do
    create table(:cites) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :target_post_id, references(:posts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:cites, [:post_id, :target_post_id])

    create table(:nntp_references) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :target_post_id, references(:posts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:nntp_references, [:post_id, :target_post_id])
  end
end
