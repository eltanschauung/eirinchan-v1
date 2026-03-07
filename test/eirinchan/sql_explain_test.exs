defmodule Eirinchan.SQLExplainTest do
  use Eirinchan.DataCase, async: false

  alias Eirinchan.SQLExplain

  test "explain returns rendered postgres output" do
    assert {:ok, result} = SQLExplain.explain("SELECT 1", repo: Repo)
    assert result.columns != []
    assert SQLExplain.render_text(result) =~ "QUERY PLAN"
  end
end
