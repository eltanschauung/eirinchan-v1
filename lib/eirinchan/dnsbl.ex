defmodule Eirinchan.DNSBL do
  @moduledoc false

  alias Eirinchan.IpMatching

  def check(ip, config, opts \\ []) do
    resolver = Keyword.get(opts, :resolver, &default_lookup/1)
    exceptions = List.wrap(Map.get(config, :dnsbl_exceptions, []))
    lists = List.wrap(Map.get(config, :dnsbl, []))

    cond do
      ipv6?(ip) -> :ok
      local_ip?(ip) -> :ok
      render_ip(ip) in exceptions -> :ok
      true -> check_lists(ip, lists, resolver)
    end
  end

  defp check_lists(_ip, [], _resolver), do: :ok

  defp check_lists(ip, [blacklist | rest], resolver) do
    {lookup_template, expectation, display_name} = normalize_blacklist(blacklist)
    reversed_ip = reverse_ipv4_octets(ip)

    lookup =
      if String.contains?(lookup_template, "%") do
        String.replace(lookup_template, "%", reversed_ip)
      else
        "#{reversed_ip}.#{lookup_template}"
      end

    case resolver.(lookup) do
      nil ->
        check_lists(ip, rest, resolver)

      response ->
        if blocked_response?(response, expectation) do
          {:error, display_name}
        else
          check_lists(ip, rest, resolver)
        end
    end
  end

  defp blocked_response?(_response, nil), do: true

  defp blocked_response?(response, expected) when is_list(expected) do
    normalized = normalize_dns_response(response)
    Enum.any?(expected, fn octet -> normalized in [to_string(octet), "127.0.0.#{octet}"] end)
  end

  defp blocked_response?(response, fun) when is_function(fun, 1),
    do: fun.(normalize_dns_response(response))

  defp blocked_response?(response, expected) do
    normalized = normalize_dns_response(response)
    normalized in [to_string(expected), "127.0.0.#{expected}"]
  end

  defp normalize_blacklist([lookup, expectation, name]), do: {lookup, expectation, name}
  defp normalize_blacklist([lookup, expectation]), do: {lookup, expectation, lookup}
  defp normalize_blacklist(lookup) when is_binary(lookup), do: {lookup, nil, lookup}

  defp default_lookup(host) do
    case :inet_res.lookup(String.to_charlist(host), :in, :a) do
      [{a, b, c, d} | _] -> "#{a}.#{b}.#{c}.#{d}"
      _ -> nil
    end
  end

  defp reverse_ipv4_octets(ip) do
    ip
    |> render_ip()
    |> String.split(".")
    |> Enum.reverse()
    |> Enum.join(".")
  end

  defp normalize_dns_response({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp normalize_dns_response(value), do: to_string(value)

  defp render_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp render_ip(ip), do: to_string(ip)

  defp ipv6?(ip) do
    case IpMatching.parse_ip(ip) do
      {:ok, {_a, _b, _c, _d, _e, _f, _g, _h}} -> true
      _ -> false
    end
  end

  defp local_ip?(ip) do
    ip_string = render_ip(ip)

    String.starts_with?(ip_string, "127.") or
      String.starts_with?(ip_string, "10.") or
      String.starts_with?(ip_string, "192.168.") or
      Regex.match?(~r/^172\.(1[6-9]|2[0-9]|3[0-1])\./, ip_string) or
      String.starts_with?(ip_string, "0.") or
      String.starts_with?(ip_string, "255.")
  end
end
