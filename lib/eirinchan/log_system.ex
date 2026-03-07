defmodule Eirinchan.LogSystem do
  @moduledoc """
  Minimal vichan-style log backend abstraction.
  """

  require Logger

  @spec log(atom(), binary(), binary(), map(), map()) :: :ok
  def log(level, event, message, metadata, config \\ %{}) do
    log_config = Map.get(config, :log_system, %{})
    rendered = render_line(level, event, message, metadata)

    case Map.get(log_config, :type, "error_log") do
      "file" ->
        write_file(Map.get(log_config, :file_path, "/var/log/vichan.log"), rendered)

      "stderr" ->
        IO.write(:stderr, rendered)

      "syslog" ->
        maybe_write_syslog(rendered, log_config)

      _ ->
        Logger.log(level, String.trim_trailing(rendered))
    end

    :ok
  end

  defp render_line(level, event, message, metadata) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    parts = [timestamp, Atom.to_string(level), event, message | render_metadata(metadata)]
    Enum.join(parts, " ") <> "\n"
  end

  defp render_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> "#{key}=#{metadata_value(value)}" end)
  end

  defp metadata_value(value) when is_binary(value), do: value
  defp metadata_value(value) when is_atom(value), do: Atom.to_string(value)
  defp metadata_value(value), do: inspect(value)

  defp write_file(path, line) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    _ = File.write(path, line, [:append])
    :ok
  end

  defp maybe_write_syslog(line, log_config) do
    if Map.get(log_config, :syslog_stderr, false) do
      IO.write(:stderr, line)
    end

    case System.find_executable("logger") do
      nil ->
        Logger.warning(String.trim_trailing(line))

      executable ->
        _ =
          System.cmd(
            executable,
            ["-t", Map.get(log_config, :name, "tinyboard"), String.trim(line)],
            stderr_to_stdout: true
          )

        :ok
    end
  end
end
