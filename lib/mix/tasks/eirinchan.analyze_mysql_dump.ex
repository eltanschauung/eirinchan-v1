defmodule Mix.Tasks.Eirinchan.AnalyzeMysqlDump do
  use Mix.Task

  @shortdoc "Analyzes a MySQL dump for supported migration tables"

  alias Eirinchan.ImportExport

  @impl true
  def run([path]) do
    case ImportExport.analyze_mysql_dump(path) do
      {:ok, analysis} -> Mix.shell().info(Jason.encode!(analysis))
      {:error, reason} -> Mix.raise("mysql analysis failed: #{inspect(reason)}")
    end
  end

  def run(_args), do: Mix.raise("usage: mix eirinchan.analyze_mysql_dump dump.sql")
end
