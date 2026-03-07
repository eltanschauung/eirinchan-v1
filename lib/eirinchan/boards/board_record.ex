defmodule Eirinchan.Boards.BoardRecord do
  use Ecto.Schema
  import Ecto.Changeset

  alias Eirinchan.Boards.Board

  schema "boards" do
    field :uri, :string
    field :title, :string
    field :subtitle, :string
    field :config_overrides, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(board, attrs) do
    board
    |> cast(attrs, [:uri, :title, :subtitle, :config_overrides])
    |> validate_required([:uri, :title])
    |> unique_constraint(:uri)
  end

  def to_board(%__MODULE__{} = record) do
    %Board{
      id: record.id,
      uri: record.uri,
      title: record.title,
      subtitle: record.subtitle,
      name: record.title,
      config_overrides: record.config_overrides || %{}
    }
  end
end
