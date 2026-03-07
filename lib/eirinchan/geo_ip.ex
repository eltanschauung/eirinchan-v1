defmodule Eirinchan.GeoIp do
  @moduledoc """
  Minimal GeoIP2 country lookup via the `mmdblookup` CLI.
  """

  @spec lookup_country(term(), map()) :: {:ok, %{code: binary(), name: binary()}} | :error
  def lookup_country(nil, _config), do: :error

  def lookup_country(remote_ip, config) do
    database_path = config[:geoip2_database_path]
    lookup_bin = config[:geoip2_lookup_bin] || "mmdblookup"

    cond do
      not is_binary(database_path) or String.trim(database_path) == "" ->
        :error

      not File.exists?(database_path) ->
        :error

      true ->
        with {:ok, code} <-
               lookup_field(lookup_bin, database_path, remote_ip, ["country", "iso_code"]),
             {:ok, name} <-
               lookup_field(lookup_bin, database_path, remote_ip, ["country", "names", "en"]) do
          {:ok, %{code: String.downcase(code), name: name}}
        else
          _ -> :error
        end
    end
  end

  defp lookup_field(lookup_bin, database_path, remote_ip, path_segments) do
    with executable when is_binary(executable) <- resolve_executable(lookup_bin),
         {output, 0} <-
           System.cmd(
             executable,
             ["--file", database_path, "--ip", to_string(remote_ip) | path_segments],
             stderr_to_stdout: true
           ),
         {:ok, value} <- parse_mmdblookup_output(output) do
      {:ok, value}
    else
      nil -> :error
      _ -> :error
    end
  end

  defp resolve_executable(lookup_bin) do
    cond do
      is_binary(lookup_bin) and String.contains?(lookup_bin, "/") and File.exists?(lookup_bin) ->
        lookup_bin

      true ->
        System.find_executable(lookup_bin)
    end
  end

  defp parse_mmdblookup_output(output) when is_binary(output) do
    case Regex.run(~r/"([^"]+)"/, output, capture: :all_but_first) do
      [value] -> {:ok, value}
      _ -> :error
    end
  end
end
