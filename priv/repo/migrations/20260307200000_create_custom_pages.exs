defmodule Eirinchan.Repo.Migrations.CreateCustomPages do
  use Ecto.Migration

  def change do
    create table(:custom_pages) do
      add :slug, :string, null: false
      add :title, :string, null: false
      add :body, :text, null: false
      add :mod_user_id, references(:mod_users, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:custom_pages, [:slug])
  end
end
