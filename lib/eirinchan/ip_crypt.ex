defmodule Eirinchan.IpCrypt do
  @moduledoc false

  alias Eirinchan.IpMatching

  @default_config %{
    enabled: true,
    cloak_key: "eirinchan-dev-ip",
    immune_ips: [],
    immune_cidrs: []
  }

  def cloak_ip(nil), do: nil

  def cloak_ip(ip) when is_binary(ip) do
    if enabled?() and not immune?(ip) do
      digest =
        :crypto.mac(:hmac, :sha256, cloak_key(), ip)
        |> Base.encode16(case: :lower)
        |> binary_part(0, 12)

      "cloaked-#{digest}"
    else
      ip
    end
  end

  def cloak_ip(ip), do: ip |> normalize_ip_string() |> cloak_ip()

  def uncloak_ip(value) when is_binary(value) do
    if valid_plain_ip?(value), do: value, else: nil
  end

  def uncloak_ip(_value), do: nil

  def immune?(ip) do
    cfg = config()
    IpMatching.match?(ip, cfg.immune_ips) or IpMatching.match?(ip, cfg.immune_cidrs)
  end

  def config do
    Map.merge(@default_config, Application.get_env(:eirinchan, :ip_privacy, %{}))
  end

  defp enabled?, do: config().enabled
  defp cloak_key, do: config().cloak_key

  defp valid_plain_ip?(value) do
    match?({:ok, _}, IpMatching.parse_ip(String.trim(value)))
  end

  defp normalize_ip_string(ip) do
    case IpMatching.normalize_ip(ip) do
      {a, b, c, d} ->
        Enum.join([a, b, c, d], ".")

      {a, b, c, d, e, f, g, h} ->
        Enum.map_join([a, b, c, d, e, f, g, h], ":", &Integer.to_string(&1, 16))

      nil ->
        to_string(ip)
    end
  end
end
