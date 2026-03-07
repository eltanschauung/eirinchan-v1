defmodule EirinchanWeb.PostManagementController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Boards.{Board, BoardRecord}
  alias Eirinchan.Moderation
  alias Eirinchan.Posts
  alias Eirinchan.Runtime.Config

  action_fallback EirinchanWeb.FallbackController

  def show(conn, %{"uri" => uri, "post_id" => post_id}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         :ok <- authorize_board(conn, board),
         {:ok, post} <- Posts.get_post(board, post_id) do
      render(conn, :show, post: post)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def update(conn, %{"uri" => uri, "post_id" => post_id} = params) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         :ok <- authorize_board(conn, board),
         {:ok, post} <-
           Posts.update_post(
             board,
             post_id,
             Map.take(params, ["name", "email", "subject", "body", "raw_html"]),
             config: board_config(board, conn.host)
           ) do
      render(conn, :show, post: post)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"uri" => uri, "post_id" => post_id}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         :ok <- authorize_board(conn, board),
         {:ok, result} <-
           Posts.moderate_delete_post(board, post_id, config: board_config(board, conn.host)) do
      json(conn, %{data: result})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete_file(conn, %{"uri" => uri, "post_id" => post_id}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         :ok <- authorize_board(conn, board),
         {:ok, post} <-
           Posts.delete_post_files(board, post_id, config: board_config(board, conn.host)) do
      render(conn, :show, post: post)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def spoiler(conn, %{"uri" => uri, "post_id" => post_id}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         :ok <- authorize_board(conn, board),
         {:ok, post} <-
           Posts.spoilerize_post_files(board, post_id, config: board_config(board, conn.host)) do
      render(conn, :show, post: post)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp authorize_board(conn, board) do
    if Moderation.board_access?(conn.assigns.current_moderator, board) do
      :ok
    else
      {:error, :forbidden}
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
