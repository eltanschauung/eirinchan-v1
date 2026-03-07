defmodule Eirinchan.Repo.Migrations.CreatePostFiles do
  use Ecto.Migration

  def change do
    create table(:post_files) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      add :file_name, :string, null: false
      add :file_path, :string, null: false
      add :thumb_path, :string
      add :file_size, :integer
      add :file_type, :string, null: false
      add :file_md5, :string, null: false
      add :image_width, :integer
      add :image_height, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:post_files, [:post_id, :position])
  end
end
