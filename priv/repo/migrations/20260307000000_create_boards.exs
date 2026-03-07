defmodule Eirinchan.Repo.Migrations.CreateBoards do
  use Ecto.Migration

  def change do
    create table(:boards) do
      add :uri, :string, null: false
      add :title, :string, null: false
      add :subtitle, :string
      add :config_overrides, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:boards, [:uri])
  end
end
