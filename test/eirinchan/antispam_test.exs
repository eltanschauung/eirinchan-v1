defmodule Eirinchan.AntispamTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Antispam

  test "search query entries are stored and rate-limited per ip and board" do
    board = board_fixture()
    request = %{remote_ip: {198, 51, 100, 44}}

    config = %{
      search_query_limit_window: 60,
      search_query_limit_count: 2,
      search_query_global_limit_window: 60,
      search_query_global_limit_count: 0
    }

    assert {:ok, _entry} =
             Antispam.log_search_query("tripcode", request, repo: Repo, board_id: board.id)

    refute Antispam.search_rate_limited?("tripcode", request, config,
             repo: Repo,
             board_id: board.id
           )

    assert {:ok, _entry} =
             Antispam.log_search_query("tripcode", request, repo: Repo, board_id: board.id)

    assert Antispam.search_rate_limited?("tripcode", request, config,
             repo: Repo,
             board_id: board.id
           )

    assert [%{query: "tripcode"}, %{query: "tripcode"}] =
             Antispam.list_search_queries("198.51.100.44", repo: Repo)
  end

  test "search queries can be rate-limited globally per board" do
    board = board_fixture()

    config = %{
      search_query_limit_window: 60,
      search_query_limit_count: 0,
      search_query_global_limit_window: 60,
      search_query_global_limit_count: 2
    }

    assert {:ok, _entry} =
             Antispam.log_search_query("tripcode", %{remote_ip: {198, 51, 100, 44}},
               repo: Repo,
               board_id: board.id
             )

    refute Antispam.search_rate_limited?("tripcode", %{remote_ip: {198, 51, 100, 55}}, config,
             repo: Repo,
             board_id: board.id
           )

    assert {:ok, _entry} =
             Antispam.log_search_query("tripcode", %{remote_ip: {198, 51, 100, 45}},
               repo: Repo,
               board_id: board.id
             )

    assert Antispam.search_rate_limited?("tripcode", %{remote_ip: {198, 51, 100, 56}}, config,
             repo: Repo,
             board_id: board.id
           )
  end
end
