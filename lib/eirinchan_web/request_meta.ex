defmodule EirinchanWeb.RequestMeta do
  @moduledoc false

  import Plug.Conn

  @default_config %{
    trust_headers: false,
    trusted_ips: [],
    trusted_cidrs: [],
    client_ip_headers: ["x-forwarded-for", "x-real-ip"]
  }

  def effective_remote_ip(conn) do
    config = config()
    remote_ip = conn.remote_ip

    if config.trust_headers and trusted_proxy?(remote_ip, config) do
      forwarded_client_ip(conn, config) || remote_ip
    else
      remote_ip
    end
  end

  def forwarded_for(conn) do
    config = config()

    if config.trust_headers and trusted_proxy?(conn.remote_ip, config) do
      conn
      |> get_req_header("x-forwarded-for")
      |> List.first()
    end
  end

  def trusted_proxy?(remote_ip, config \\ config()) do
    exact_match?(remote_ip, config.trusted_ips) or cidr_match?(remote_ip, config.trusted_cidrs)
  end

  defp forwarded_client_ip(conn, config) do
    Enum.find_value(config.client_ip_headers, fn header ->
      conn
      |> get_req_header(header)
      |> List.first()
      |> extract_client_ip(header)
    end)
  end

  defp extract_client_ip(nil, _header), do: nil

  defp extract_client_ip(value, "x-forwarded-for") do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.find_value(&parsed_ip/1)
  end

  defp extract_client_ip(value, _header), do: parsed_ip(String.trim(value))

  defp exact_match?(remote_ip, candidates) do
    normalized_remote = normalize_ip(remote_ip)

    Enum.any?(List.wrap(candidates), fn candidate ->
      normalize_ip(candidate) == normalized_remote
    end)
  end

  defp cidr_match?(remote_ip, cidrs) do
    with {:ok, remote_binary} <- ip_to_binary(remote_ip) do
      Enum.any?(List.wrap(cidrs), &ip_in_cidr?(remote_binary, &1))
    else
      _ -> false
    end
  end

  defp ip_in_cidr?(remote_binary, cidr) do
    with [address, prefix] <- String.split(to_string(cidr), "/", parts: 2),
         {prefix_size, ""} <- Integer.parse(prefix),
         {:ok, network_ip} <- parse_ip(address),
         {:ok, network_binary} <- ip_to_binary(network_ip),
         true <- byte_size(remote_binary) == byte_size(network_binary),
         true <- prefix_size >= 0 and prefix_size <= byte_size(remote_binary) * 8 do
      <<remote_prefix::bitstring-size(prefix_size), _::bitstring>> = remote_binary
      <<network_prefix::bitstring-size(prefix_size), _::bitstring>> = network_binary
      remote_prefix == network_prefix
    else
      _ -> false
    end
  end

  defp parse_ip(value) when is_binary(value) do
    value
    |> String.to_charlist()
    |> :inet.parse_address()
  end

  defp parse_ip(value) when is_tuple(value), do: {:ok, value}
  defp parse_ip(_value), do: :error

  defp parsed_ip(value) do
    case parse_ip(value) do
      {:ok, ip} -> ip
      _ -> nil
    end
  end

  defp ip_to_binary({a, b, c, d}), do: {:ok, <<a, b, c, d>>}

  defp ip_to_binary({a, b, c, d, e, f, g, h}) do
    {:ok, <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>}
  end

  defp ip_to_binary(_value), do: :error

  defp normalize_ip(ip) do
    case parse_ip(ip) do
      {:ok, parsed} -> parsed
      _ -> nil
    end
  end

  defp config do
    @default_config
    |> Map.merge(Application.get_env(:eirinchan, :proxy_request, %{}))
    |> Map.update!(:trusted_ips, &List.wrap/1)
    |> Map.update!(:trusted_cidrs, &List.wrap/1)
    |> Map.update!(
      :client_ip_headers,
      &Enum.map(List.wrap(&1), fn value -> String.downcase(to_string(value)) end)
    )
  end
end
