defmodule EirinchanWeb.IpPresentation do
  @moduledoc false

  @default_config %{cloak_key: "eirinchan-ip"}

  def show_raw_ip?(%{role: role}) when role in ["admin", "mod"], do: true
  def show_raw_ip?(_moderator), do: false

  def display_ip(nil, _moderator), do: nil

  def display_ip(ip, moderator) do
    if show_raw_ip?(moderator) do
      ip
    else
      cloak_ip(ip)
    end
  end

  def cloak_ip(ip) when is_binary(ip) do
    digest =
      :crypto.mac(:hmac, :sha256, cloak_key(), ip)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    "cloaked-#{digest}"
  end

  def cloak_ip(ip), do: cloak_ip(to_string(ip))

  defp cloak_key do
    Application.get_env(:eirinchan, :ip_privacy, %{})
    |> Map.get(:cloak_key, @default_config.cloak_key)
  end
end
