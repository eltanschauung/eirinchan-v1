defmodule Eirinchan.Repo.Migrations.AddPostMetadataFields do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :tag, :string
      add :proxy, :string
      add :tripcode, :string
      add :capcode, :string
      add :raw_html, :boolean, default: false, null: false
    end
  end
end
