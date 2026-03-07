defmodule EirinchanWeb.IpManagementController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Moderation

  action_fallback EirinchanWeb.FallbackController

  def board_show(conn, %{"uri" => uri, "ip" => ip}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         :ok <- authorize_board(conn, board) do
      posts = Moderation.list_ip_posts(ip, board_ids: [board.id])
      notes = Moderation.list_ip_notes(ip, board_id: board.id)
      render(conn, :show, ip: ip, posts: posts, notes: notes)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def show(conn, %{"ip" => ip}) do
    boards = Moderation.list_accessible_boards(conn.assigns.current_moderator)
    posts = Moderation.list_ip_posts(ip, board_ids: Enum.map(boards, & &1.id))
    notes = Moderation.list_ip_notes(ip)
    render(conn, :show, ip: ip, posts: posts, notes: notes)
  end

  def create_note(conn, %{"uri" => uri, "ip" => ip, "body" => body}) do
    with board when not is_nil(board) <- Boards.get_board_by_uri(uri),
         :ok <- authorize_board(conn, board),
         {:ok, note} <-
           Moderation.add_ip_note(ip, %{
             body: body,
             board_id: board.id,
             mod_user_id: conn.assigns.current_moderator.id
           }) do
      conn
      |> put_status(:created)
      |> render(:note, note: note)
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
end
