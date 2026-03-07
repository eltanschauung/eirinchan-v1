defmodule Mix.Tasks.EirinchanExplainSqlTest do
  use Eirinchan.DataCase, async: false

  import ExUnit.CaptureIO

  test "explain task prints postgres output" do
    output =
      capture_io(fn ->
        Mix.Tasks.Eirinchan.ExplainSql.run(["SELECT", "1"])
      end)

    assert output =~ "QUERY PLAN"
  end
end
