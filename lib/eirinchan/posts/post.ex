defmodule Eirinchan.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :name, :string
    field :email, :string
    field :subject, :string
    field :password, :string
    field :body, :string
    field :bump_at, :utc_datetime_usec
    field :sticky, :boolean, default: false
    field :locked, :boolean, default: false
    field :cycle, :boolean, default: false
    field :sage, :boolean, default: false
    field :slug, :string

    belongs_to :board, Eirinchan.Boards.BoardRecord
    belongs_to :thread, __MODULE__

    timestamps(type: :utc_datetime)
  end

  def create_changeset(post, attrs) do
    post
    |> cast(attrs, [
      :board_id,
      :thread_id,
      :name,
      :email,
      :subject,
      :password,
      :body,
      :bump_at,
      :sticky,
      :locked,
      :cycle,
      :sage,
      :slug
    ])
    |> update_change(:name, &normalize_string/1)
    |> update_change(:email, &normalize_string/1)
    |> update_change(:subject, &normalize_string/1)
    |> update_change(:password, &normalize_string/1)
    |> update_change(:body, &normalize_body/1)
    |> validate_required([:board_id, :body])
    |> foreign_key_constraint(:board_id)
    |> foreign_key_constraint(:thread_id)
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

  defp normalize_body(nil), do: nil
  defp normalize_body(value), do: String.trim(value)
end
