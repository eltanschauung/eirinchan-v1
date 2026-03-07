defmodule EirinchanWeb.SiteAssetsLayoutTest do
  use EirinchanWeb.ConnCase, async: false

  setup do
    previous =
      Application.get_env(:eirinchan, :site_assets, %{version: nil, custom_javascript: []})

    on_exit(fn ->
      Application.put_env(:eirinchan, :site_assets, previous)
    end)

    :ok
  end

  test "root layout appends cache-busting versions and includes configured custom javascript", %{
    conn: conn
  } do
    Application.put_env(:eirinchan, :site_assets, %{
      version: "build-42",
      custom_javascript: "/js/custom-a.js, /js/custom-b.js\n/js/custom-c.js"
    })

    page =
      conn
      |> get("/search", %{"q" => ""})
      |> html_response(200)

    assert page =~ ~s(/assets/app.css?v=build-42)
    assert page =~ ~s(/assets/app.js?v=build-42)
    assert page =~ ~s(/js/custom-a.js?v=build-42)
    assert page =~ ~s(/js/custom-b.js?v=build-42)
    assert page =~ ~s(/js/custom-c.js?v=build-42)
  end
end
