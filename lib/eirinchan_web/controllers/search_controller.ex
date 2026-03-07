defmodule EirinchanWeb.SearchController do
  use EirinchanWeb, :controller

  alias Eirinchan.Announcement
  alias Eirinchan.Antispam
  alias Eirinchan.Boards
  alias Eirinchan.CustomPages
  alias Eirinchan.Posts
  alias Eirinchan.Runtime.Config

  def show(conn, params) do
    query = String.trim(params["q"] || "")
    board = board_from_param(params["board"])
    config = search_config(board)
    request = %{remote_ip: conn.remote_ip}

    cond do
      query == "" ->
        render_search(conn, query, board, [], nil)

      Antispam.search_rate_limited?(query, request, config, board_id: board && board.id) ->
        render_search(conn, query, board, [], "Search rate limit exceeded.")

      true ->
        _ = Antispam.log_search_query(query, request, board_id: board && board.id)

        results =
          Posts.list_recent_posts(
            limit: 50,
            board_ids: if(board, do: [board.id], else: nil),
            query: query
          )
          |> Eirinchan.Repo.preload(:board)

        render_search(conn, query, board, results, nil)
    end
  end

  defp render_search(conn, query, board, results, error) do
    render(conn, :show,
      query: query,
      board: board,
      boards: Boards.list_boards(),
      announcement: Announcement.current(),
      custom_pages: CustomPages.list_pages(),
      results: results,
      error: error
    )
  end

  defp board_from_param(nil), do: nil
  defp board_from_param(""), do: nil
  defp board_from_param(uri), do: Boards.get_board_by_uri(uri)

  defp search_config(nil), do: Config.compose()

  defp search_config(board_record) do
    Config.compose(nil, %{}, board_record.config_overrides || %{},
      board: Eirinchan.Boards.BoardRecord.to_board(board_record)
    )
  end
end
