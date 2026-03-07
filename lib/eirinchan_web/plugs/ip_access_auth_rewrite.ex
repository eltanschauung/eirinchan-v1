defmodule EirinchanWeb.Plugs.IpAccessAuthRewrite do
  @moduledoc false

  import Plug.Conn

  alias Eirinchan.IpAccessAuth
  alias Eirinchan.Settings

  def init(opts), do: opts

  def call(conn, _opts) do
    config = ip_access_auth_config()

    if conn.request_path != "/auth" and
         IpAccessAuth.configured_for_path?(conn.request_path, config) do
      conn
      |> Map.put(:request_path, "/auth")
      |> Map.put(:path_info, ["auth"])
      |> assign(:ip_access_auth_request_path, conn.request_path)
    else
      conn
    end
  end

  defp ip_access_auth_config do
    Settings.current_instance_config()
    |> Map.get(:ip_access_auth, %{})
  end
end
