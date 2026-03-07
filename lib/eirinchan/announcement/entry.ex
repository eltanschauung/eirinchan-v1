defmodule Eirinchan.Announcement.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "announcement_entries" do
    field :title, :string
    field :body, :string

    belongs_to :mod_user, Eirinchan.Moderation.ModUser

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:title, :body, :mod_user_id])
    |> update_change(:title, &normalize/1)
    |> update_change(:body, &normalize/1)
    |> validate_required([:title, :body, :mod_user_id])
    |> foreign_key_constraint(:mod_user_id)
  end

  defp normalize(nil), do: nil

  defp normalize(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
