defmodule Eirinchan.Boardlist do
  @moduledoc """
  Instance-configurable boardlist groups.
  """

  alias Eirinchan.Settings

  @spec configured_groups(list()) :: list()
  def configured_groups(boards) when is_list(boards) do
    case Settings.current_instance_config() |> Map.get(:boardlist) do
      groups when is_list(groups) ->
        groups
        |> Enum.map(&normalize_group(&1, boards))
        |> Enum.reject(&(&1 == []))

      _ ->
        default_groups(boards)
    end
  end

  @spec update_from_json(binary(), list()) :: {:ok, list()} | {:error, :invalid_json}
  def update_from_json(raw_json, boards) when is_binary(raw_json) and is_list(boards) do
    with {:ok, decoded} <- Jason.decode(raw_json),
         true <- is_list(decoded),
         groups <- Enum.map(decoded, &normalize_group(&1, boards)),
         true <- Enum.all?(groups, &(is_list(&1) and &1 != [])),
         :ok <- persist(groups) do
      {:ok, groups}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      false -> {:error, :invalid_json}
      {:error, _reason} = error -> error
      _ -> {:error, :invalid_json}
    end
  end

  @spec encode_for_edit(list()) :: binary()
  def encode_for_edit(boards) when is_list(boards) do
    boards
    |> configured_groups()
    |> Enum.map(fn group ->
      Enum.map(group, fn link ->
        case Map.get(link, :kind, :link) do
          :board -> link.label
          _ -> %{link.label => link.href}
        end
      end)
      |> collapse_group()
    end)
    |> Jason.encode!(pretty: true)
  end

  defp collapse_group(items) do
    cond do
      Enum.all?(items, &is_binary/1) ->
        items

      true ->
        Enum.reduce(items, %{}, fn
          item, acc when is_map(item) -> Map.merge(acc, item)
          _item, acc -> acc
        end)
    end
  end

  defp persist(groups) do
    config = Settings.current_instance_config()
    Settings.persist_instance_config(Map.put(config, :boardlist, groups))
  end

  defp default_groups(boards) do
    [
      Enum.map(boards, fn board ->
        %{label: board.uri, href: "/#{board.uri}/index.html", title: board.title, kind: :board}
      end),
      [%{href: "/", label: "Home", title: "Home", kind: :link}]
    ]
    |> Enum.reject(&(&1 == []))
  end

  defp normalize_group(group, boards) when is_list(group) do
    group
    |> Enum.map(&normalize_item(&1, boards))
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_group(group, boards) when is_map(group) do
    group
    |> Enum.map(&normalize_pair(&1, boards))
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_group(_group, _boards), do: []

  defp normalize_item(item, boards) when is_binary(item) do
    board =
      Enum.find(boards, fn board ->
        board.uri == String.trim(item)
      end)

    label = String.trim(item)

    if label == "" do
      nil
    else
      %{
        label: label,
        href: "/#{label}/index.html",
        title: (board && board.title) || label,
        kind: :board
      }
    end
  end

  defp normalize_item(_item, _boards), do: nil

  defp normalize_pair({label, href}, boards) when is_binary(label) do
    normalized_label = String.trim(label)
    normalized_href = href |> to_string() |> String.trim()

    cond do
      normalized_label == "" or normalized_href == "" ->
        nil

      true ->
        board = Enum.find(boards, &(&1.uri == normalized_label))

        %{
          label: normalized_label,
          href: normalized_href,
          title: (board && board.title) || normalized_label,
          kind: :link
        }
    end
  end

  defp normalize_pair(_pair, _boards), do: nil
end
