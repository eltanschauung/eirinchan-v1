defmodule Eirinchan.AccessList do
  @moduledoc false

  alias Eirinchan.IpMatching

  @default_config %{enabled: false, entries: [], path: nil}

  def enabled? do
    config().enabled
  end

  def allowed?(ip) do
    cfg = config()

    if cfg.enabled do
      IpMatching.match?(ip, entries(cfg))
    else
      true
    end
  end

  def ip_matches_access_list?(ip, entries) do
    IpMatching.match?(ip, entries)
  end

  def entries(cfg \\ config()) do
    inline_entries = List.wrap(cfg.entries)
    file_entries = load_file_entries(cfg.path)
    inline_entries ++ file_entries
  end

  def config do
    Map.merge(@default_config, Application.get_env(:eirinchan, :ip_access_list, %{}))
  end

  defp load_file_entries(nil), do: []
  defp load_file_entries(""), do: []

  defp load_file_entries(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split(~r/\R/u, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    else
      []
    end
  end
end
