defmodule Eirinchan.Posts.Cite do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cites" do
    belongs_to :post, Eirinchan.Posts.Post
    belongs_to :target_post, Eirinchan.Posts.Post

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(cite, attrs) do
    cite
    |> cast(attrs, [:post_id, :target_post_id])
    |> validate_required([:post_id, :target_post_id])
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:target_post_id)
    |> unique_constraint([:post_id, :target_post_id])
  end
end
