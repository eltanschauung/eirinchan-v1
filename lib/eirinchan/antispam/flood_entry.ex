defmodule Eirinchan.Antispam.FloodEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "flood_entries" do
    field :ip_subnet, :string
    field :body_hash, :string

    belongs_to :board, Eirinchan.Boards.BoardRecord

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:board_id, :ip_subnet, :body_hash])
    |> validate_required([:board_id, :ip_subnet])
    |> foreign_key_constraint(:board_id)
  end
end
