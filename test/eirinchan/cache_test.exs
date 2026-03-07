defmodule Eirinchan.CacheTest do
  use ExUnit.Case, async: false

  alias Eirinchan.Cache

  test "driver selection follows vichan-style names" do
    assert Cache.driver(%{cache: %{enabled: false}}) == "none"
    assert Cache.driver(%{cache: %{enabled: true}}) == "php"
    assert Cache.driver(%{cache: %{enabled: "apcu"}}) == "apcu"
    assert Cache.driver(%{cache: %{enabled: "fs"}}) == "fs"
    assert Cache.driver(%{cache: %{enabled: "redis"}}) == "redis"
    assert Cache.driver(%{cache: %{enabled: "memcached"}}) == "memcached"
  end

  test "memory-backed php/apcu style drivers round-trip values" do
    config = %{cache: %{enabled: "php"}}
    assert :ok = Cache.flush(config)
    assert :ok = Cache.put("noticeboard", %{body: "hello"}, 60, config)
    assert Cache.get("noticeboard", config) == %{body: "hello"}

    apcu_config = %{cache: %{enabled: "apcu"}}
    assert :ok = Cache.put("noticeboard", "cached", 60, apcu_config)
    assert Cache.get("noticeboard", apcu_config) == "cached"
  end

  test "filesystem cache driver persists and expires entries" do
    root = Path.join(System.tmp_dir!(), "eirinchan-cache-#{System.unique_integer([:positive])}")
    config = %{cache: %{enabled: "fs", fs_path: root, prefix: "test_"}}
    _ = File.rm_rf(root)

    assert :ok = Cache.put("banner", ["a.png"], 1, config)
    assert Cache.get("banner", config) == ["a.png"]

    Process.sleep(1100)
    assert Cache.get("banner", config) == nil
  end

  test "none driver is a no-op" do
    config = %{cache: %{enabled: "none"}}
    assert :ok = Cache.put("x", 1, 60, config)
    assert Cache.get("x", config) == nil
  end
end
