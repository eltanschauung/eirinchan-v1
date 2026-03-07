defmodule Eirinchan.LogSystemTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias Eirinchan.LogSystem

  test "error_log backend writes through Logger" do
    log =
      capture_log(fn ->
        assert :ok ==
                 LogSystem.log(
                   :warning,
                   "post.error",
                   "post.error",
                   %{reason: :invalid_captcha, board: "test"},
                   %{log_system: %{type: "error_log"}}
                 )
      end)

    assert log =~ "post.error"
    assert log =~ "reason=invalid_captcha"
    assert log =~ "board=test"
  end

  test "file backend appends rendered lines to the configured file" do
    path = Path.join(System.tmp_dir!(), "eirinchan-log-#{System.unique_integer([:positive])}.log")
    File.rm(path)

    assert :ok ==
             LogSystem.log(
               :warning,
               "post.error",
               "post.error",
               %{reason: :duplicate_file, board: "tech"},
               %{log_system: %{type: "file", file_path: path}}
             )

    log = File.read!(path)
    assert log =~ "post.error"
    assert log =~ "reason=duplicate_file"
    assert log =~ "board=tech"
  end

  test "stderr backend writes to stderr" do
    output =
      capture_io(:stderr, fn ->
        assert :ok ==
                 LogSystem.log(
                   :warning,
                   "post.error",
                   "post.error",
                   %{reason: :invalid_password, board: "meta"},
                   %{log_system: %{type: "stderr"}}
                 )
      end)

    assert output =~ "post.error"
    assert output =~ "reason=invalid_password"
    assert output =~ "board=meta"
  end

  test "syslog backend can mirror to stderr" do
    output =
      capture_io(:stderr, fn ->
        assert :ok ==
                 LogSystem.log(
                   :warning,
                   "post.error",
                   "post.error",
                   %{reason: :banned, board: "tea"},
                   %{log_system: %{type: "syslog", syslog_stderr: true, name: "tinyboard"}}
                 )
      end)

    assert output =~ "post.error"
    assert output =~ "reason=banned"
    assert output =~ "board=tea"
  end

  test "json-formatted logs emit structured metadata" do
    output =
      capture_io(:stderr, fn ->
        assert :ok ==
                 LogSystem.log(
                   :warning,
                   "post.error",
                   "post.error",
                   %{reason: :invalid_password, board: "meta", log_format: "json"},
                   %{log_system: %{type: "stderr"}}
                 )
      end)

    decoded = Jason.decode!(String.trim(output))
    assert decoded["event"] == "post.error"
    assert decoded["metadata"]["reason"] == "invalid_password"
    assert decoded["metadata"]["board"] == "meta"
  end
end
