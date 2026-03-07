defmodule EirinchanWeb.BanAppealManagementJSON do
  def index(%{appeals: appeals}) do
    %{data: Enum.map(appeals, &appeal_data/1)}
  end

  def show(%{appeal: appeal}) do
    %{data: appeal_data(appeal)}
  end

  defp appeal_data(appeal) do
    %{
      id: appeal.id,
      ban_id: appeal.ban_id,
      body: appeal.body,
      status: appeal.status,
      resolution_note: appeal.resolution_note,
      resolved_at: appeal.resolved_at
    }
  end
end
