defmodule EirinchanWeb.BanManagementJSON do
  def index(%{bans: bans}) do
    %{data: Enum.map(bans, &ban_data/1)}
  end

  def show(%{ban: ban}) do
    %{data: ban_data(ban)}
  end

  defp ban_data(ban) do
    %{
      id: ban.id,
      board_id: ban.board_id,
      mod_user_id: ban.mod_user_id,
      ip_subnet: ban.ip_subnet,
      reason: ban.reason,
      expires_at: ban.expires_at,
      active: ban.active
    }
  end
end
