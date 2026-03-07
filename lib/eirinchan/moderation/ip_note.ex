defmodule Eirinchan.Moderation.IpNote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ip_notes" do
    field :ip_subnet, :string
    field :body, :string

    belongs_to :board, Eirinchan.Boards.BoardRecord
    belongs_to :mod_user, Eirinchan.Moderation.ModUser

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(ip_note, attrs) do
    ip_note
    |> cast(attrs, [:ip_subnet, :body, :board_id, :mod_user_id])
    |> validate_required([:ip_subnet, :body])
    |> foreign_key_constraint(:board_id)
    |> foreign_key_constraint(:mod_user_id)
  end
end
