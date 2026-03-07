defmodule Eirinchan.IpAccessAuthTest do
  use ExUnit.Case, async: false

  alias Eirinchan.IpAccessAuth

  setup do
    original_path = Application.get_env(:eirinchan, :instance_config_path)

    path =
      Path.join(
        System.tmp_dir!(),
        "eirinchan-ipauth-settings-#{System.unique_integer([:positive])}.json"
      )

    File.rm(path)
    Application.put_env(:eirinchan, :instance_config_path, path)

    on_exit(fn ->
      Application.put_env(:eirinchan, :instance_config_path, original_path)
      File.rm(path)
    end)

    :ok
  end

  test "uses default passwords when configured list is blank" do
    config = IpAccessAuth.effective_config(%{passwords: ""})
    assert config.passwords == ["password", "nigel", "whitehouse"]
  end

  test "normalizes comma-separated passwords and deduplicates case-insensitively" do
    config = IpAccessAuth.effective_config(%{passwords: " Foo,bar,foo , BAR "})
    assert config.passwords == ["foo", "bar"]
  end

  test "derives ipv4 and ipv6 subnets" do
    assert IpAccessAuth.subnet_for_ip({187, 180, 254, 75}) == {:ok, "187.180.254.0/24"}
    assert IpAccessAuth.subnet_for_ip("2001:db8:abcd:1234::1") == {:ok, "2001:db8:abcd::/48"}
  end

  test "appends the subnet and log comment once" do
    access_file =
      Path.join(System.tmp_dir!(), "ipauth-access-#{System.unique_integer([:positive])}.conf")

    File.rm(access_file)

    config = %{access_file: access_file, passwords: "door", auth_path: "/auth"}

    assert {:ok, %{subnet: "203.0.113.0/24"}} =
             IpAccessAuth.authorize({203, 0, 113, 9}, "door", config)

    first_body = File.read!(access_file)
    assert first_body =~ "203.0.113.0/24"
    assert first_body =~ "#door "
    assert first_body =~ "203.0.113.9"

    assert {:ok, %{subnet: "203.0.113.0/24"}} =
             IpAccessAuth.authorize({203, 0, 113, 9}, "door", config)

    assert File.read!(access_file) == first_body
  end

  test "resolves relative access file paths from the project root inferred from settings path" do
    access_file = IpAccessAuth.access_file_path(%{access_file: "var/ipauth/access.conf"})
    assert String.ends_with?(access_file, "/var/ipauth/access.conf")
  end
end
