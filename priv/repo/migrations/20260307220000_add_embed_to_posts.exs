defmodule Eirinchan.Repo.Migrations.AddEmbedToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :embed, :text
    end
  end
end
