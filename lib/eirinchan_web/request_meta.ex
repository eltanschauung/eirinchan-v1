defmodule EirinchanWeb.RequestMeta do
  @moduledoc false

  alias Eirinchan.IpMatching
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
    IpMatching.match?(remote_ip, config.trusted_ips) or
      IpMatching.match?(remote_ip, config.trusted_cidrs)
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

  defp parse_ip(value) when is_binary(value) do
    IpMatching.parse_ip(value)
  end

  defp parse_ip(value) when is_tuple(value), do: {:ok, value}
  defp parse_ip(_value), do: :error

  defp parsed_ip(value) do
    case parse_ip(value) do
      {:ok, ip} -> ip
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
