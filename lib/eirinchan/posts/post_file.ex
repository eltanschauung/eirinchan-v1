defmodule Eirinchan.Posts.PostFile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "post_files" do
    field :position, :integer
    field :file_name, :string
    field :file_path, :string
    field :thumb_path, :string
    field :file_size, :integer
    field :file_type, :string
    field :file_md5, :string
    field :image_width, :integer
    field :image_height, :integer

    belongs_to :post, Eirinchan.Posts.Post

    timestamps(type: :utc_datetime)
  end

  def create_changeset(post_file, attrs) do
    post_file
    |> cast(attrs, [
      :post_id,
      :position,
      :file_name,
      :file_path,
      :thumb_path,
      :file_size,
      :file_type,
      :file_md5,
      :image_width,
      :image_height
    ])
    |> validate_required([:post_id, :position, :file_name, :file_path, :file_type, :file_md5])
    |> foreign_key_constraint(:post_id)
  end
end
