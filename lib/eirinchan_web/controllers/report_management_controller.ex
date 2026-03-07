defmodule EirinchanWeb.ReportManagementController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Reports

  action_fallback EirinchanWeb.FallbackController

  def index(conn, %{"uri" => uri}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri) do
      render(conn, :index, reports: Reports.list_reports(board))
    else
      nil -> {:error, :not_found}
    end
  end

  def delete(conn, %{"uri" => uri, "id" => id}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         {:ok, _report} <- Reports.dismiss_report(board, id) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end
end
