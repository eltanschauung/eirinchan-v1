defmodule Eirinchan.IpMatching do
  @moduledoc false

  def match?(ip, entries) do
    Enum.any?(List.wrap(entries), &entry_match?(ip, &1))
  end

  def entry_match?(ip, entry) do
    value = to_string(entry)

    if String.contains?(value, "/") do
      ip_in_cidr?(ip, value)
    else
      normalize_ip(ip) == normalize_ip(value)
    end
  end

  def normalize_ip(ip) do
    case parse_ip(ip) do
      {:ok, parsed} -> parsed
      _ -> nil
    end
  end

  def parse_ip(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.to_charlist()
    |> :inet.parse_address()
  end

  def parse_ip(value) when is_tuple(value), do: {:ok, value}
  def parse_ip(_value), do: :error

  def ip_in_cidr?(ip, cidr) do
    with [address, prefix] <- String.split(to_string(cidr), "/", parts: 2),
         {prefix_size, ""} <- Integer.parse(prefix),
         {:ok, ip_binary} <- ip_to_binary(ip),
         {:ok, network_ip} <- parse_ip(address),
         {:ok, network_binary} <- ip_to_binary(network_ip),
         true <- byte_size(ip_binary) == byte_size(network_binary),
         true <- prefix_size >= 0 and prefix_size <= byte_size(ip_binary) * 8 do
      <<ip_prefix::bitstring-size(prefix_size), _::bitstring>> = ip_binary
      <<network_prefix::bitstring-size(prefix_size), _::bitstring>> = network_binary
      ip_prefix == network_prefix
    else
      _ -> false
    end
  end

  defp ip_to_binary({a, b, c, d}), do: {:ok, <<a, b, c, d>>}

  defp ip_to_binary({a, b, c, d, e, f, g, h}) do
    {:ok, <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>}
  end

  defp ip_to_binary(value) when is_binary(value) do
    case parse_ip(value) do
      {:ok, parsed} -> ip_to_binary(parsed)
      _ -> :error
    end
  end

  defp ip_to_binary(_value), do: :error
end
