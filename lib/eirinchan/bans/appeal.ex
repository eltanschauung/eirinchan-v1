defmodule Eirinchan.Bans.Appeal do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ban_appeals" do
    field :body, :string
    field :status, :string, default: "open"
    field :resolution_note, :string
    field :resolved_at, :utc_datetime_usec

    belongs_to :ban, Eirinchan.Bans.Ban

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(appeal, attrs) do
    appeal
    |> cast(attrs, [:ban_id, :body, :status, :resolution_note, :resolved_at])
    |> validate_required([:ban_id, :body, :status])
    |> validate_inclusion(:status, ["open", "resolved", "rejected"])
    |> foreign_key_constraint(:ban_id)
  end
end
