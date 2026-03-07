defmodule Eirinchan.FeedbackImportTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Feedback

  test "import_legacy_file loads feedback.txt style entries into the database" do
    path =
      Path.join(
        System.tmp_dir!(),
        "eirinchan-feedback-#{System.unique_integer([:positive])}.txt"
      )

    File.write!(
      path,
      """
      ---
      Name: Alice
      Email: alice@example.com
      IP: 203.0.113.0/16
      Body:
      First legacy feedback

      ---
      Name: Bob
      Body:
      Second legacy feedback
      """
    )

    on_exit(fn -> File.rm(path) end)

    assert {:ok, %{imported: 2}} = Feedback.import_legacy_file(path)

    [first, second] = Feedback.list_feedback()
    assert first.name == "Alice"
    assert first.email == "alice@example.com"
    assert first.ip_subnet == "203.0.113.0/16"
    assert first.body == "First legacy feedback"
    assert second.name == "Bob"
    assert second.ip_subnet == "0.0.0.0"
    assert second.body == "Second legacy feedback"
  end
end
