defmodule Eirinchan.AccessList do
  @moduledoc false

  alias Eirinchan.IpMatching

  @default_config %{enabled: false, entries: []}

  def enabled? do
    config().enabled
  end

  def allowed?(ip) do
    cfg = config()

    if cfg.enabled do
      IpMatching.match?(ip, cfg.entries)
    else
      true
    end
  end

  def ip_matches_access_list?(ip, entries) do
    IpMatching.match?(ip, entries)
  end

  def config do
    Map.merge(@default_config, Application.get_env(:eirinchan, :ip_access_list, %{}))
  end
end
