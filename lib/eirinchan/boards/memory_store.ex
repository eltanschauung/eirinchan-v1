defmodule Eirinchan.Boards.MemoryStore do
  @moduledoc false

  alias Eirinchan.Boards.Board

  @spec fetch_by_uri(String.t(), keyword()) :: {:ok, Board.t()} | {:error, :not_found}
  def fetch_by_uri(uri, opts) do
    boards = Keyword.get(opts, :boards, %{})

    case Map.get(boards, uri) do
      nil -> {:error, :not_found}
      %Board{} = board -> {:ok, board}
      attrs when is_map(attrs) -> {:ok, struct(Board, attrs)}
    end
  end
end
