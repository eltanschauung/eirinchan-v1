defmodule EirinchanWeb.IpPresentation do
  @moduledoc false

  alias Eirinchan.IpCrypt

  def show_raw_ip?(%{role: role}) when role in ["admin", "mod"], do: true
  def show_raw_ip?(_moderator), do: false

  def display_ip(nil, _moderator), do: nil

  def display_ip(ip, moderator) do
    if show_raw_ip?(moderator) do
      ip
    else
      IpCrypt.cloak_ip(ip)
    end
  end
end
