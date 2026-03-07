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
    |> update_change(:uri, &normalize_uri/1)
    |> validate_format(:uri, ~r/\A[a-zA-Z0-9_]+\z/)
    |> validate_length(:uri, min: 1, max: 32)
    |> validate_length(:title, min: 1, max: 255)
    |> unique_constraint(:uri)
  end

  def to_board(%__MODULE__{} = record) do
    %Board{
      id: record.id,
      uri: record.uri,
      title: record.title,
      subtitle: record.subtitle,
      name: record.title,
      config_overrides: normalize_config_overrides(record.config_overrides || %{})
    }
  end

  defp normalize_uri(uri) when is_binary(uri), do: uri |> String.trim() |> String.trim("/")
  defp normalize_uri(uri), do: uri

  defp normalize_config_overrides(overrides) when is_map(overrides) do
    Enum.into(overrides, %{}, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), normalize_nested(value)}
      {key, value} when is_atom(key) -> {key, normalize_nested(value)}
    end)
  rescue
    ArgumentError ->
      Enum.into(overrides, %{}, fn {key, value} -> {key, normalize_nested(value)} end)
  end

  defp normalize_nested(value) when is_map(value), do: normalize_config_overrides(value)
  defp normalize_nested(value) when is_list(value), do: Enum.map(value, &normalize_nested/1)
  defp normalize_nested(value), do: value
end
