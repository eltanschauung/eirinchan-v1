defmodule Eirinchan.Feedback.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "feedback_comments" do
    field :body, :string

    belongs_to :feedback, Eirinchan.Feedback.Entry

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:feedback_id, :body])
    |> update_change(:body, &normalize_string/1)
    |> validate_required([:feedback_id, :body])
    |> foreign_key_constraint(:feedback_id)
    |> validate_length(:body, min: 1, max: 4000)
  end

  defp normalize_string(nil), do: nil

  defp normalize_string(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
