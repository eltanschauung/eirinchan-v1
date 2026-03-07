defmodule Eirinchan.Locking do
  @moduledoc false

  def with_exclusive_lock(config, key, fun) when is_function(fun, 0) do
    case driver(config) do
      "fs" -> with_fs_lock(config, key, fun)
      _ -> fun.()
    end
  end

  def driver(%{lock: lock}), do: driver(lock)

  def driver(config) when is_map(config) do
    case Map.get(config, :enabled, Map.get(config, :driver, "none")) do
      value when value in [true, "fs"] -> "fs"
      value when value in ["none", false, nil] -> "none"
      value when is_binary(value) -> value
      _ -> "none"
    end
  end

  def driver(_config), do: "none"

  defp with_fs_lock(config, key, fun) do
    root =
      config
      |> Map.get(:path, "tmp/locks")
      |> Path.expand(project_root())

    _ = File.mkdir_p(root)
    path = Path.join(root, sanitize_key(key) <> ".lock")

    acquire_lock(path, 100)

    try do
      fun.()
    after
      _ = File.rm_rf(path)
    end
  end

  defp acquire_lock(path, 0), do: raise("unable to acquire lock #{path}")

  defp acquire_lock(path, attempts_left) do
    case File.mkdir(path) do
      :ok ->
        :ok

      {:error, :eexist} ->
        Process.sleep(10)
        acquire_lock(path, attempts_left - 1)

      {:error, _reason} ->
        Process.sleep(10)
        acquire_lock(path, attempts_left - 1)
    end
  end

  defp sanitize_key(key) do
    key
    |> to_string()
    |> String.replace("/", "::")
    |> String.replace("\0", "")
  end

  defp project_root do
    case Application.get_env(:eirinchan, :instance_config_path) do
      path when is_binary(path) -> Path.expand("..", Path.dirname(path))
      _ -> File.cwd!()
    end
  end
end
