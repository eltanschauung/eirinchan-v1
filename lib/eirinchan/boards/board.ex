defmodule Eirinchan.Boards.Board do
  @moduledoc """
  Domain representation of a board and its runtime overrides.
  """

  @enforce_keys [:uri, :title]
  defstruct [
    :id,
    :uri,
    :title,
    subtitle: nil,
    name: nil,
    dir: nil,
    url: nil,
    config_overrides: %{}
  ]

  @type t :: %__MODULE__{
          id: term(),
          uri: String.t(),
          title: String.t(),
          subtitle: String.t() | nil,
          name: String.t() | nil,
          dir: String.t() | nil,
          url: String.t() | nil,
          config_overrides: map()
        }

  @spec with_runtime_paths(t(), map()) :: t()
  def with_runtime_paths(%__MODULE__{} = board, config) do
    dir = board.dir || format_string(config.board_path, board.uri)
    url = board.url || format_string(config.board_abbreviation, board.uri)

    %{board | dir: dir, url: url, name: board.name || board.title}
  end

  defp format_string(template, value) do
    String.replace(template, "%s", value)
  end
end
