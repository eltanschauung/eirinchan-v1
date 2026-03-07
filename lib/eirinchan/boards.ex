defmodule Eirinchan.Boards do
  @moduledoc """
  Board context loading modeled after vichan's `openBoard`.
  """

  alias Eirinchan.Boards.{Board, EctoStore}
  alias Eirinchan.Runtime
  alias Eirinchan.Runtime.{Config, RequestContext}

  @spec open_board(String.t(), keyword()) :: {:ok, RequestContext.t()} | {:error, :not_found}
  def open_board(uri, opts \\ []) do
    context = Keyword.get_lazy(opts, :context, fn -> Runtime.bootstrap(opts) end)

    case context do
      %RequestContext{board: %Board{uri: ^uri}} ->
        {:ok, context}

      %RequestContext{} ->
        do_open_board(uri, context, opts)
    end
  end

  defp do_open_board(uri, %RequestContext{} = context, opts) do
    {store, store_opts} = Keyword.get(opts, :board_store, {EctoStore, []})

    with {:ok, board} <- store.fetch_by_uri(uri, store_opts) do
      board = Board.with_runtime_paths(board, context.config)

      effective_config =
        Config.compose(
          Keyword.get(opts, :defaults),
          Keyword.get(opts, :instance_overrides, %{}),
          board.config_overrides,
          board: board,
          request_host: Keyword.get(opts, :request_host)
        )

      {:ok, %RequestContext{context | board: board, config: effective_config}}
    end
  end
end
