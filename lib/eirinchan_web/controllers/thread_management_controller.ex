defmodule EirinchanWeb.ThreadManagementController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Boards.{Board, BoardRecord}
  alias Eirinchan.Posts
  alias Eirinchan.Runtime.Config

  action_fallback EirinchanWeb.FallbackController

  def show(conn, %{"uri" => uri, "thread_id" => thread_id}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         {:ok, [thread | _]} <- Posts.get_thread(board, thread_id) do
      render(conn, :show, thread: thread)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def update(conn, %{"uri" => uri, "thread_id" => thread_id} = params) do
    with board_record when not is_nil(board_record) <- Boards.get_board_by_uri(uri),
         {:ok, thread} <-
           Posts.update_thread_state(
             board_record,
             thread_id,
             Map.take(params, ["sticky", "locked", "cycle", "sage"]),
             config: board_config(board_record, conn.host)
           ) do
      render(conn, :show, thread: thread)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp board_config(%BoardRecord{} = board_record, request_host) do
    board =
      board_record
      |> BoardRecord.to_board()
      |> Board.with_runtime_paths(Config.compose())

    Config.compose(nil, %{}, board_record.config_overrides,
      board: board,
      request_host: request_host
    )
  end
end
