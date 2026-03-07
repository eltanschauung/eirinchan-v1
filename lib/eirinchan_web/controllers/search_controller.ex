defmodule EirinchanWeb.SearchController do
  use EirinchanWeb, :controller

  alias Eirinchan.Announcement
  alias Eirinchan.Antispam
  alias Eirinchan.Boards
  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.CustomPages
  alias Eirinchan.Posts
  alias Eirinchan.Runtime.Config

  def show(conn, params) do
    query = String.trim(params["q"] || "")
    board = board_from_param(params["board"])
    instance_overrides = Application.get_env(:eirinchan, :search_overrides, %{})
    config = search_config(board, instance_overrides)
    boards = searchable_boards(instance_overrides)
    request = %{remote_ip: conn.remote_ip}

    cond do
      not search_enabled?(config) ->
        render_search(conn, query, board, boards, [], "Search disabled.")

      board && not board_searchable?(board, config) ->
        render_search(conn, query, board, boards, [], "Search not available for this board.")

      query == "" ->
        render_search(conn, query, board, boards, [], nil)

      Antispam.search_rate_limited?(query, request, config, board_id: board && board.id) ->
        render_search(conn, query, board, boards, [], "Search rate limit exceeded.")

      true ->
        _ = Antispam.log_search_query(query, request, board_id: board && board.id)

        board_ids =
          if board do
            [board.id]
          else
            Enum.map(boards, & &1.id)
          end

        results =
          Posts.list_recent_posts(
            limit: 50,
            board_ids: board_ids,
            query: query
          )
          |> Eirinchan.Repo.preload(:board)

        render_search(conn, query, board, boards, results, nil)
    end
  end

  defp render_search(conn, query, board, boards, results, error) do
    render(conn, :show,
      query: query,
      board: board,
      boards: boards,
      announcement: Announcement.current(),
      custom_pages: CustomPages.list_pages(),
      results: results,
      error: error
    )
  end

  defp board_from_param(nil), do: nil
  defp board_from_param(""), do: nil
  defp board_from_param(uri), do: Boards.get_board_by_uri(uri)

  defp search_config(nil, instance_overrides), do: Config.compose(nil, instance_overrides, %{})

  defp search_config(board_record, instance_overrides) do
    Config.compose(nil, instance_overrides, board_record.config_overrides || %{},
      board: Eirinchan.Boards.BoardRecord.to_board(board_record)
    )
  end

  defp searchable_boards(instance_overrides) do
    Boards.list_boards()
    |> Enum.filter(fn board ->
      board_searchable?(board, search_config(board, instance_overrides))
    end)
  end

  defp board_searchable?(%BoardRecord{} = board, config) do
    search_enabled?(config) and allowed_board?(board.uri, config)
  end

  defp search_enabled?(config), do: Map.get(config, :search_enabled, true)

  defp allowed_board?(uri, config) do
    allowed = normalize_uri_list(Map.get(config, :search_allowed_boards))
    disallowed = normalize_uri_list(Map.get(config, :search_disallowed_boards, []))

    (allowed == nil or uri in allowed) and uri not in disallowed
  end

  defp normalize_uri_list(nil), do: nil

  defp normalize_uri_list(values) when is_list(values) do
    Enum.map(values, &normalize_uri/1)
  end

  defp normalize_uri_list(value), do: [normalize_uri(value)]

  defp normalize_uri(uri) when is_binary(uri), do: uri |> String.trim() |> String.trim("/")
  defp normalize_uri(uri), do: to_string(uri)
end
