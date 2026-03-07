defmodule EirinchanWeb.Plugs.FetchSiteAssets do
  @moduledoc false

  import Plug.Conn

  @default_config %{
    version: nil,
    custom_javascript: []
  }

  def init(opts), do: opts

  def call(conn, _opts) do
    config = config()

    conn
    |> assign(:asset_version, blank_to_nil(config.version))
    |> assign(:custom_javascript_urls, parse_custom_javascript(config.custom_javascript))
  end

  def parse_custom_javascript(value) when is_list(value) do
    value
    |> Enum.flat_map(&parse_custom_javascript/1)
    |> Enum.uniq()
  end

  def parse_custom_javascript(value) when is_binary(value) do
    value
    |> String.split(~r/[\n,]/u, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def parse_custom_javascript(nil), do: []
  def parse_custom_javascript(_value), do: []

  defp config do
    Map.merge(@default_config, Application.get_env(:eirinchan, :site_assets, %{}))
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
