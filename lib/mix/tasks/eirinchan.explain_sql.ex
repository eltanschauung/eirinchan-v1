defmodule Mix.Tasks.Eirinchan.ExplainSql do
  use Mix.Task

  @shortdoc "Runs EXPLAIN against a SQL statement"

  alias Eirinchan.SQLExplain

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    sql = Enum.join(args, " ") |> String.trim()

    if sql == "" do
      Mix.raise("usage: mix eirinchan.explain_sql \"SELECT ...\"")
    end

    case SQLExplain.explain(sql) do
      {:ok, result} ->
        Mix.shell().info(SQLExplain.render_text(result))

      {:error, error} ->
        Mix.raise("explain failed: #{Exception.message(error)}")
    end
  end
end
