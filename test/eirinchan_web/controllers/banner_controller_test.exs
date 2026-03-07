defmodule EirinchanWeb.BannerControllerTest do
  use EirinchanWeb.ConnCase, async: false

  setup do
    original_path = Application.get_env(:eirinchan, :instance_config_path)

    path =
      Path.join(System.tmp_dir!(), "eirinchan-banners-#{System.unique_integer([:positive])}.json")

    File.rm(path)
    Application.put_env(:eirinchan, :instance_config_path, path)

    on_exit(fn ->
      Application.put_env(:eirinchan, :instance_config_path, original_path)
      File.rm(path)
    end)

    :ok
  end

  test "b.php redirects to a configured banner path", %{conn: conn} do
    :ok = Eirinchan.Settings.persist_instance_config(%{banners: ["/images/logo.svg"]})

    conn = get(conn, "/b.php")

    assert redirected_to(conn, 302) == "/images/logo.svg"
  end

  test "b.php returns not found when no banners are configured", %{conn: conn} do
    conn = get(conn, "/b.php")

    assert response(conn, 404) == "No banners configured."
  end
end
