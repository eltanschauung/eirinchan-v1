defmodule Eirinchan.Moderation.ModMessage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Eirinchan.Moderation.ModUser

  schema "mod_messages" do
    field :subject, :string
    field :body, :string
    field :read_at, :utc_datetime_usec

    belongs_to :sender, ModUser
    belongs_to :recipient, ModUser
    belongs_to :reply_to, __MODULE__

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:subject, :body, :read_at, :sender_id, :recipient_id, :reply_to_id])
    |> update_change(:subject, &normalize_optional/1)
    |> update_change(:body, &normalize_optional/1)
    |> validate_required([:body, :sender_id, :recipient_id])
    |> validate_length(:subject, max: 255)
    |> assoc_constraint(:sender)
    |> assoc_constraint(:recipient)
    |> assoc_constraint(:reply_to)
  end

  def read_changeset(message, attrs) do
    cast(message, attrs, [:read_at])
  end

  defp normalize_optional(nil), do: nil

  defp normalize_optional(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
