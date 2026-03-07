defmodule Eirinchan.AccessListTest do
  use ExUnit.Case, async: true

  alias Eirinchan.AccessList

  test "ip_matches_access_list supports single ips and cidr ranges" do
    assert AccessList.ip_matches_access_list?({198, 51, 100, 7}, ["198.51.100.7"])
    assert AccessList.ip_matches_access_list?({198, 51, 100, 7}, ["198.51.100.0/24"])

    assert AccessList.ip_matches_access_list?(
             {0x2001, 0x0DB8, 0xABCD, 0x1, 0, 0, 0, 1},
             ["2001:db8:abcd::/48"]
           )

    refute AccessList.ip_matches_access_list?({198, 51, 100, 7}, ["203.0.113.0/24"])
  end
end
