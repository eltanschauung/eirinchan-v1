defmodule EirinchanWeb.ThemeManagementControllerTest do
  use EirinchanWeb.ConnCase, async: false

  setup do
    original_path = Application.get_env(:eirinchan, :instance_config_path)

    path =
      Path.join(System.tmp_dir!(), "eirinchan-themes-#{System.unique_integer([:positive])}.json")

    File.rm(path)
    Application.put_env(:eirinchan, :instance_config_path, path)

    on_exit(fn ->
      Application.put_env(:eirinchan, :instance_config_path, original_path)
      File.rm(path)
    end)

    :ok
  end

  test "admin can install, select, and uninstall custom themes", %{conn: conn} do
    moderator = moderator_fixture(%{role: "admin"})

    install_conn =
      conn
      |> login_moderator(moderator)
      |> post("/manage/themes/browser", %{
        "name" => "ocean",
        "label" => "Ocean",
        "stylesheet" => "/stylesheets/ocean.css"
      })

    assert redirected_to(install_conn) == "/manage/themes/browser"

    themes_page =
      install_conn
      |> recycle()
      |> login_moderator(moderator)
      |> get("/manage/themes/browser")
      |> html_response(200)

    assert themes_page =~ "Theme Registry"
    assert themes_page =~ "Ocean"

    select_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> patch("/manage/themes/browser/ocean", %{"default_theme" => "ocean"})

    assert redirected_to(select_conn) == "/manage/themes/browser"
    assert Eirinchan.Settings.default_theme() == "ocean"

    themed_page =
      conn
      |> recycle()
      |> get("/search", %{"q" => ""})
      |> html_response(200)

    assert themed_page =~ ~s(<option value="ocean" selected>)

    uninstall_conn =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> delete("/manage/themes/browser/ocean")

    assert redirected_to(uninstall_conn) == "/manage/themes/browser"
    refute Enum.any?(Eirinchan.Settings.installed_themes(), &(&1.name == "ocean"))
  end
end
