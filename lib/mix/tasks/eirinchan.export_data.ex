defmodule Mix.Tasks.Eirinchan.ExportData do
  use Mix.Task

  @shortdoc "Exports application data to a JSON file"

  alias Eirinchan.ImportExport

  @impl true
  def run([path]) do
    Mix.Task.run("app.start")

    case ImportExport.export_file(path) do
      {:ok, _path} -> Mix.shell().info("exported #{path}")
      {:error, reason} -> Mix.raise("export failed: #{inspect(reason)}")
    end
  end

  def run(_args), do: Mix.raise("usage: mix eirinchan.export_data path.json")
end
