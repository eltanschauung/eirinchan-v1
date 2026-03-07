defmodule Eirinchan.Repo.Migrations.AddFileFieldsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :file_name, :string
      add :file_path, :string
      add :file_size, :integer
      add :file_type, :string
      add :file_md5, :string
    end
  end
end
