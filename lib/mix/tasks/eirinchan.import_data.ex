defmodule Mix.Tasks.Eirinchan.ImportData do
  use Mix.Task

  @shortdoc "Imports application data from a JSON file"

  alias Eirinchan.ImportExport

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, paths, _invalid} =
      OptionParser.parse(args, strict: [dry_run: :boolean, no_idempotent: :boolean])

    case paths do
      [path] ->
        case ImportExport.import_file(path,
               dry_run: Keyword.get(opts, :dry_run, false),
               idempotent: not Keyword.get(opts, :no_idempotent, false)
             ) do
          {:ok, counts} -> Mix.shell().info(Jason.encode!(counts))
          {:error, reason} -> Mix.raise("import failed: #{inspect(reason)}")
        end

      _ ->
        Mix.raise("usage: mix eirinchan.import_data [--dry-run] [--no-idempotent] path.json")
    end
  end
end
