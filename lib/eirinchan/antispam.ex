defmodule Eirinchan.Antispam do
  @moduledoc """
  Minimal flood/search tracking compatible with vichan-style posting throttles.
  """

  import Ecto.Query, only: [from: 2]

  alias Eirinchan.Antispam.{FloodEntry, SearchQuery}
  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Repo

  def check_post(%BoardRecord{} = board, attrs, request, config, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    ip_subnet = request_ip(request)
    now = DateTime.utc_now()

    cond do
      is_nil(ip_subnet) ->
        :ok

      config.flood_time_ip > 0 and
          recent_ip_post?(repo, board.id, ip_subnet, now, config.flood_time_ip) ->
        {:error, :antispam}

      config.flood_time_same > 0 and
          repeated_body?(repo, board.id, ip_subnet, attrs, now, config.flood_time_same) ->
        {:error, :antispam}

      true ->
        :ok
    end
  end

  def log_post(%BoardRecord{} = board, attrs, request, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    %FloodEntry{}
    |> FloodEntry.changeset(%{
      board_id: board.id,
      ip_subnet: request_ip(request),
      body_hash: body_hash(attrs)
    })
    |> repo.insert()
  end

  def log_search_query(query, request, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    board_id = Keyword.get(opts, :board_id)

    %SearchQuery{}
    |> SearchQuery.changeset(%{
      board_id: board_id,
      ip_subnet: request_ip(request),
      query: normalize_query(query)
    })
    |> repo.insert()
  end

  def search_rate_limited?(query, request, config, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    board_id = Keyword.get(opts, :board_id)
    ip_subnet = request_ip(request)

    if is_nil(ip_subnet) or config.search_query_limit_count <= 0 do
      false
    else
      cutoff = DateTime.add(DateTime.utc_now(), -config.search_query_limit_window, :second)

      query =
        from(entry in SearchQuery,
          where:
            entry.ip_subnet == ^ip_subnet and entry.query == ^normalize_query(query) and
              entry.inserted_at >= ^cutoff,
          select: count(entry.id)
        )

      count =
        case board_id do
          nil -> repo.one(query)
          _ -> repo.one(from(entry in query, where: entry.board_id == ^board_id))
        end

      count >= config.search_query_limit_count
    end
  end

  def list_flood_entries(ip_subnet, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    from(entry in FloodEntry,
      where: entry.ip_subnet == ^normalize_ip(ip_subnet),
      order_by: [asc: entry.inserted_at]
    )
    |> repo.all()
  end

  def list_search_queries(ip_subnet, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    from(entry in SearchQuery,
      where: entry.ip_subnet == ^normalize_ip(ip_subnet),
      order_by: [asc: entry.inserted_at]
    )
    |> repo.all()
  end

  defp recent_ip_post?(repo, board_id, ip_subnet, now, window_seconds) do
    cutoff = DateTime.add(now, -window_seconds, :second)

    from(entry in FloodEntry,
      where:
        entry.board_id == ^board_id and entry.ip_subnet == ^ip_subnet and
          entry.inserted_at >= ^cutoff,
      select: count(entry.id)
    )
    |> repo.one()
    |> Kernel.>(0)
  end

  defp repeated_body?(repo, board_id, ip_subnet, attrs, now, window_seconds) do
    cutoff = DateTime.add(now, -window_seconds, :second)
    current_body_hash = body_hash(attrs)

    if is_nil(current_body_hash) do
      false
    else
      from(entry in FloodEntry,
        where:
          entry.board_id == ^board_id and entry.ip_subnet == ^ip_subnet and
            entry.body_hash == ^current_body_hash and entry.inserted_at >= ^cutoff,
        select: count(entry.id)
      )
      |> repo.one()
      |> Kernel.>(0)
    end
  end

  defp body_hash(attrs) do
    case Map.get(attrs, "body") |> normalize_query() do
      nil ->
        nil

      body ->
        :sha256
        |> :crypto.hash(body)
        |> Base.encode16(case: :lower)
    end
  end

  defp request_ip(request) do
    request
    |> Map.get(:remote_ip, Map.get(request, "remote_ip"))
    |> normalize_ip()
  end

  defp normalize_query(nil), do: nil

  defp normalize_query(query) when is_binary(query) do
    query
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_query(query), do: to_string(query)

  defp normalize_ip({a, b, c, d}), do: Enum.join([a, b, c, d], ".")

  defp normalize_ip({a, b, c, d, e, f, g, h}) do
    [a, b, c, d, e, f, g, h]
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.join(":")
  end

  defp normalize_ip(ip) when is_binary(ip), do: String.trim(ip)
  defp normalize_ip(_ip), do: nil
end
