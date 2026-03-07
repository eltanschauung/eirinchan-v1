defmodule Eirinchan.IpCryptTest do
  use ExUnit.Case, async: false

  alias Eirinchan.IpCrypt

  setup do
    previous = Application.get_env(:eirinchan, :ip_privacy, %{})

    on_exit(fn ->
      Application.put_env(:eirinchan, :ip_privacy, previous)
    end)

    :ok
  end

  test "cloak_ip hashes visible addresses by default" do
    Application.put_env(:eirinchan, :ip_privacy, %{enabled: true, cloak_key: "test-key"})

    cloaked = IpCrypt.cloak_ip("198.51.100.7")

    assert cloaked =~ "cloaked-"
    refute cloaked == "198.51.100.7"
  end

  test "immune single ips and cidr ranges bypass cloaking" do
    Application.put_env(:eirinchan, :ip_privacy, %{
      enabled: true,
      cloak_key: "test-key",
      immune_ips: ["198.51.100.7"],
      immune_cidrs: ["2001:db8:abcd::/48"]
    })

    assert IpCrypt.cloak_ip("198.51.100.7") == "198.51.100.7"
    assert IpCrypt.cloak_ip("2001:db8:abcd:1:0:0:0:1") == "2001:db8:abcd:1:0:0:0:1"

    refute IpCrypt.cloak_ip("203.0.113.9") == "203.0.113.9"
  end

  test "uncloak_ip accepts already-plain valid ips" do
    assert IpCrypt.uncloak_ip("198.51.100.7") == "198.51.100.7"
    assert IpCrypt.uncloak_ip("2001:db8:abcd::1") == "2001:db8:abcd::1"
    assert IpCrypt.uncloak_ip("cloaked-deadbeef") == nil
  end
end
