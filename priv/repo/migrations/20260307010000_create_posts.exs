defmodule Eirinchan.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :board_id, references(:boards, on_delete: :delete_all), null: false
      add :thread_id, references(:posts, on_delete: :delete_all)
      add :name, :string
      add :email, :string
      add :subject, :string
      add :password, :string
      add :body, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:posts, [:board_id, :inserted_at])
    create index(:posts, [:board_id, :thread_id, :inserted_at])
  end
end
