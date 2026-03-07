defmodule EirinchanWeb.BoardManagementController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards

  action_fallback EirinchanWeb.FallbackController

  def index(conn, _params) do
    render(conn, :index, boards: Boards.list_boards())
  end

  def create(conn, params) do
    with {:ok, board} <- Boards.create_board(params) do
      conn
      |> put_status(:created)
      |> render(:show, board: board)
    end
  end

  def show(conn, %{"uri" => uri}) do
    case Boards.get_board_by_uri(uri) do
      nil -> {:error, :not_found}
      board -> render(conn, :show, board: board)
    end
  end

  def update(conn, %{"uri" => uri} = params) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         {:ok, board} <- Boards.update_board(board, Map.delete(params, "uri")) do
      render(conn, :show, board: board)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"uri" => uri}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         {:ok, _board} <- Boards.delete_board(board) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end
end
