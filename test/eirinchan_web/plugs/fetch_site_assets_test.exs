defmodule EirinchanWeb.Plugs.FetchSiteAssetsTest do
  use ExUnit.Case, async: true

  alias EirinchanWeb.Plugs.FetchSiteAssets

  test "parse_custom_javascript accepts comma and newline separated values" do
    assert FetchSiteAssets.parse_custom_javascript("/js/one.js, /js/two.js\n/js/three.js") == [
             "/js/one.js",
             "/js/two.js",
             "/js/three.js"
           ]
  end

  test "parse_custom_javascript flattens lists and removes duplicates" do
    assert FetchSiteAssets.parse_custom_javascript([
             "/js/one.js, /js/two.js",
             ["/js/two.js", "/js/three.js"]
           ]) == ["/js/one.js", "/js/two.js", "/js/three.js"]
  end
end
