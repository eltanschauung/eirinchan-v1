defmodule Eirinchan.SQLExplain do
  @moduledoc false

  alias Eirinchan.Repo

  def explain(sql, opts \\ []) when is_binary(sql) do
    repo = Keyword.get(opts, :repo, Repo)
    sql = String.trim(sql)

    case repo.query("EXPLAIN #{sql}") do
      {:ok, result} ->
        {:ok, %{columns: result.columns, rows: result.rows}}

      {:error, error} ->
        {:error, error}
    end
  end

  def render_text(%{columns: columns, rows: rows}) do
    rendered_rows =
      Enum.map(rows, fn row ->
        row
        |> Enum.map(&to_string/1)
        |> Enum.join("\t")
      end)

    [Enum.join(columns, "\t") | rendered_rows]
    |> Enum.join("\n")
  end
end
