defmodule Mix.Tasks.Eirinchan.ImportFeedback do
  use Mix.Task

  @shortdoc "Imports legacy feedback.txt entries into the database"

  def run([path]) do
    Mix.Task.run("app.start")

    case Eirinchan.Feedback.import_legacy_file(path) do
      {:ok, %{imported: count}} ->
        Mix.shell().info("Imported #{count} feedback entries.")

      {:error, reason} ->
        Mix.raise("feedback import failed: #{inspect(reason)}")
    end
  end

  def run(_args) do
    Mix.raise("usage: mix eirinchan.import_feedback PATH")
  end
end
