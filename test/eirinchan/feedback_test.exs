defmodule Eirinchan.FeedbackTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Feedback

  test "create_feedback stores body and redacted ip when ip storage is disabled" do
    assert {:ok, entry} =
             Feedback.create_feedback(
               %{"name" => "Anon", "body" => "Useful feedback"},
               remote_ip: {203, 0, 113, 9},
               store_ip: false
             )

    assert entry.body == "Useful feedback"
    assert entry.ip_subnet == "0.0.0.0"
  end

  test "create_feedback stores masked ip ranges when enabled" do
    assert {:ok, ipv4_entry} =
             Feedback.create_feedback(
               %{"body" => "IPv4 feedback"},
               remote_ip: {192, 168, 5, 25},
               store_ip: true
             )

    assert ipv4_entry.ip_subnet == "192.168.0.0/16"

    assert {:ok, ipv6_entry} =
             Feedback.create_feedback(
               %{"body" => "IPv6 feedback"},
               remote_ip: {0x2001, 0x0DB8, 0xABCD, 0x1, 0, 0, 0, 1},
               store_ip: true
             )

    assert ipv6_entry.ip_subnet == "2001:db8:abcd::/48"
  end

  test "mark_read and add_comment update the moderation view of feedback" do
    assert {:ok, entry} =
             Feedback.create_feedback(%{"body" => "Initial feedback"}, remote_ip: {127, 0, 0, 1})

    assert {:ok, _comment} = Feedback.add_comment(entry.id, %{"body" => "Internal note"})
    assert {:ok, _entry} = Feedback.mark_read(entry.id)

    loaded = Feedback.get_feedback(entry.id)
    assert loaded.read_at
    assert Enum.map(loaded.comments, & &1.body) == ["Internal note"]
  end
end
