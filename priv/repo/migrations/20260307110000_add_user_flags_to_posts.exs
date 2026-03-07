defmodule Eirinchan.Repo.Migrations.AddUserFlagsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :flag_codes, {:array, :string}, default: []
      add :flag_alts, {:array, :string}, default: []
    end
  end
end
