defmodule Eirinchan.ReportsTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Reports

  test "create_report stores board, post, thread, and reason" do
    board = board_fixture()
    thread = thread_fixture(board)

    {:ok, reply, _meta} =
      Eirinchan.Posts.create_post(
        board,
        %{
          "thread" => Integer.to_string(thread.id),
          "body" => "Reply body",
          "post" => "New Reply"
        },
        config: Eirinchan.Runtime.Config.compose(nil, %{}, board.config_overrides),
        request: %{referer: "http://example.test/#{board.uri}/index.html"}
      )

    assert {:ok, report} =
             Reports.create_report(board, %{
               "report_post_id" => Integer.to_string(reply.id),
               "reason" => "Spam reply"
             })

    assert report.board_id == board.id
    assert report.post_id == reply.id
    assert report.thread_id == thread.id
    assert report.reason == "Spam reply"
  end

  test "dismiss_report removes a report from the active queue" do
    board = board_fixture()
    thread = thread_fixture(board)

    assert {:ok, report} =
             Reports.create_report(board, %{
               "report_post_id" => Integer.to_string(thread.id),
               "reason" => "Rule violation"
             })

    assert Enum.map(Reports.list_reports(board), & &1.id) == [report.id]

    assert {:ok, dismissed} = Reports.dismiss_report(board, report.id)
    assert dismissed.dismissed_at
    assert Reports.list_reports(board) == []
  end
end
