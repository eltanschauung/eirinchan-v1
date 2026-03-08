defmodule Eirinchan.DNSBLConfig do
  @moduledoc """
  Instance-configurable DNSBL settings.
  """

  alias Eirinchan.Settings
  alias Eirinchan.Runtime.Config

  @spec encode_entries_for_edit() :: binary()
  def encode_entries_for_edit do
    current_entries()
    |> Jason.encode!(pretty: true)
  end

  @spec encode_exceptions_for_edit() :: binary()
  def encode_exceptions_for_edit do
    current_exceptions()
    |> Enum.join("\n")
  end

  @spec update(binary(), binary()) :: {:ok, map()} | {:error, :invalid_json}
  def update(entries_json, exceptions_text)
      when is_binary(entries_json) and is_binary(exceptions_text) do
    with {:ok, decoded} <- Jason.decode(entries_json),
         true <- is_list(decoded),
         entries <- Enum.map(decoded, &normalize_entry/1),
         true <- Enum.all?(entries, &(&1 != :invalid)),
         exceptions <- parse_exceptions(exceptions_text),
         :ok <- persist(entries, exceptions) do
      {:ok, %{dnsbl: entries, dnsbl_exceptions: exceptions}}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      false -> {:error, :invalid_json}
      {:error, _reason} = error -> error
      _ -> {:error, :invalid_json}
    end
  end

  defp current_entries do
    Settings.current_instance_config()
    |> Map.get(:dnsbl, Config.default_config().dnsbl)
    |> List.wrap()
  end

  defp current_exceptions do
    Settings.current_instance_config()
    |> Map.get(:dnsbl_exceptions, Config.default_config().dnsbl_exceptions)
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_exceptions(text) do
    text
    |> String.split(~r/[\r\n,]+/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp persist(entries, exceptions) do
    config = Settings.current_instance_config()

    Settings.persist_instance_config(
      config
      |> Map.put(:dnsbl, entries)
      |> Map.put(:dnsbl_exceptions, exceptions)
    )
  end

  defp normalize_entry(entry) when is_binary(entry) do
    value = String.trim(entry)
    if value == "", do: :invalid, else: value
  end

  defp normalize_entry([lookup, expectation, display_name])
       when is_binary(lookup) and is_binary(display_name) do
    with {:ok, normalized_lookup} <- normalize_nonempty_string(lookup),
         {:ok, normalized_expectation} <- normalize_expectation(expectation),
         {:ok, normalized_name} <- normalize_nonempty_string(display_name) do
      [normalized_lookup, normalized_expectation, normalized_name]
    else
      _ -> :invalid
    end
  end

  defp normalize_entry([lookup, expectation]) when is_binary(lookup) do
    with {:ok, normalized_lookup} <- normalize_nonempty_string(lookup),
         {:ok, normalized_expectation} <- normalize_expectation(expectation) do
      [normalized_lookup, normalized_expectation]
    else
      _ -> :invalid
    end
  end

  defp normalize_entry(%{} = entry) do
    lookup = Map.get(entry, "lookup") || Map.get(entry, :lookup)
    expectation = Map.get(entry, "expectation") || Map.get(entry, :expectation)
    display_name = Map.get(entry, "display_name") || Map.get(entry, :display_name)

    cond do
      is_nil(lookup) or is_nil(expectation) ->
        :invalid

      is_nil(display_name) ->
        normalize_entry([lookup, expectation])

      true ->
        normalize_entry([lookup, expectation, display_name])
    end
  end

  defp normalize_entry(_entry), do: :invalid

  defp normalize_expectation(value) when is_integer(value), do: {:ok, value}

  defp normalize_expectation(values) when is_list(values) do
    if Enum.all?(values, &is_integer/1) do
      {:ok, values}
    else
      :invalid
    end
  end

  defp normalize_expectation(%{} = value) do
    type = Map.get(value, "type") || Map.get(value, :type)

    case to_string(type || "") |> String.trim() do
      "httpbl" ->
        max_days = Map.get(value, "max_days") || Map.get(value, :max_days)
        min_threat = Map.get(value, "min_threat") || Map.get(value, :min_threat)

        if is_integer(max_days) and is_integer(min_threat) do
          {:ok, %{type: "httpbl", max_days: max_days, min_threat: min_threat}}
        else
          :invalid
        end

      _ ->
        :invalid
    end
  end

  defp normalize_expectation(_value), do: :invalid

  defp normalize_nonempty_string(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: :invalid, else: {:ok, trimmed}
  end
end
