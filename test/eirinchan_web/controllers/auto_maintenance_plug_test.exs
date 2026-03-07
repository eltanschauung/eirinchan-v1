defmodule EirinchanWeb.AutoMaintenancePlugTest do
  use EirinchanWeb.ConnCase, async: false

  alias Eirinchan.Settings

  setup do
    original_path = Application.get_env(:eirinchan, :instance_config_path)

    path =
      Path.join(
        System.tmp_dir!(),
        "eirinchan-maintenance-settings-#{System.unique_integer([:positive])}.json"
      )

    File.rm(path)
    Application.put_env(:eirinchan, :instance_config_path, path)

    on_exit(fn ->
      Application.put_env(:eirinchan, :instance_config_path, original_path)
      File.rm(path)
    end)

    :ok
  end

  test "browser requests trigger auto maintenance when enabled", %{conn: conn} do
    board = board_fixture()

    {:ok, _ban} =
      Eirinchan.Bans.create_ban(%{
        board_id: board.id,
        ip_subnet: "203.0.113.0/24",
        reason: "expired",
        active: true,
        expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
      })

    {:ok, _config} =
      Settings.update_instance_config_from_json(
        Jason.encode!(%{auto_maintenance: true, maintenance_interval_seconds: 0})
      )

    _ = get(conn, "/")
    assert Enum.empty?(Eirinchan.Bans.list_bans(board_id: board.id))
  end
end
