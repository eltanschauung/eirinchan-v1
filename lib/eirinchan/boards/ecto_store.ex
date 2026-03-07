defmodule Eirinchan.Boards.EctoStore do
  @moduledoc """
  Default board store backed by PostgreSQL.
  """

  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Repo

  @spec fetch_by_uri(String.t(), keyword()) ::
          {:ok, Eirinchan.Boards.Board.t()} | {:error, :not_found}
  def fetch_by_uri(uri, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    schema = Keyword.get(opts, :schema, BoardRecord)

    case repo.get_by(schema, uri: uri) do
      nil -> {:error, :not_found}
      record -> {:ok, schema.to_board(record)}
    end
  end
end
