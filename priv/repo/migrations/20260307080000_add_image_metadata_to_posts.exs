defmodule Eirinchan.Repo.Migrations.AddImageMetadataToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :thumb_path, :string
      add :image_width, :integer
      add :image_height, :integer
    end
  end
end
