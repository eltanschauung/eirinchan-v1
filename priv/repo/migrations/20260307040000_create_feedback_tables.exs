defmodule Eirinchan.Repo.Migrations.CreateFeedbackTables do
  use Ecto.Migration

  def change do
    create table(:feedback) do
      add :name, :string
      add :email, :string
      add :body, :text, null: false
      add :ip_subnet, :string, null: false
      add :read_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create table(:feedback_comments) do
      add :feedback_id, references(:feedback, on_delete: :delete_all), null: false
      add :body, :text, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:feedback, [:read_at, :inserted_at])
    create index(:feedback_comments, [:feedback_id, :inserted_at])
  end
end
