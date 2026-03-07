defmodule Eirinchan.Cache do
  @moduledoc """
  Minimal cache driver abstraction with vichan-style driver names.
  """

  @table :eirinchan_cache

  def driver(config \\ %{}) do
    cache = normalize_config(config)
    enabled = Map.get(cache, :enabled, false)
    configured = Map.get(cache, :driver)

    cond do
      is_binary(enabled) and enabled != "" -> enabled
      is_binary(configured) and configured != "" -> configured
      enabled == true -> "php"
      true -> "none"
    end
  end

  def get(key, config \\ %{}) do
    case driver(config) do
      "none" -> nil
      "fs" -> get_fs(key, normalize_config(config))
      _ -> get_memory(key)
    end
  end

  def put(key, value, ttl_seconds \\ nil, config \\ %{}) do
    case driver(config) do
      "none" ->
        :ok

      "fs" ->
        put_fs(key, value, ttl_seconds, normalize_config(config))

      _ ->
        put_memory(key, value, ttl_seconds)
    end
  end

  def delete(key, config \\ %{}) do
    case driver(config) do
      "none" -> :ok
      "fs" -> delete_fs(key, normalize_config(config))
      _ -> delete_memory(key)
    end
  end

  def flush(config \\ %{}) do
    case driver(config) do
      "none" ->
        :ok

      "fs" ->
        config
        |> normalize_config()
        |> fs_root()
        |> File.rm_rf()

      _ ->
        ensure_table()
        :ets.delete_all_objects(@table)
        :ok
    end
  end

  defp get_memory(key) do
    ensure_table()

    case :ets.lookup(@table, key) do
      [{^key, expires_at, value}] ->
        if expired?(expires_at) do
          :ets.delete(@table, key)
          nil
        else
          value
        end

      _ ->
        nil
    end
  end

  defp put_memory(key, value, ttl_seconds) do
    ensure_table()
    true = :ets.insert(@table, {key, expiry_timestamp(ttl_seconds), value})
    :ok
  end

  defp delete_memory(key) do
    ensure_table()
    :ets.delete(@table, key)
    :ok
  end

  defp get_fs(key, config) do
    path = fs_path(config, key)

    with true <- File.exists?(path),
         {:ok, binary} <- File.read(path),
         {:ok, %{expires_at: expires_at, value: value}} <- safe_binary_to_term(binary),
         false <- expired?(expires_at) do
      value
    else
      true ->
        nil

      _ ->
        _ = File.rm(path)
        nil
    end
  end

  defp put_fs(key, value, ttl_seconds, config) do
    path = fs_path(config, key)
    _ = File.mkdir_p(Path.dirname(path))

    payload = %{expires_at: expiry_timestamp(ttl_seconds), value: value}
    File.write(path, :erlang.term_to_binary(payload))
  end

  defp delete_fs(key, config) do
    _ = File.rm(fs_path(config, key))
    :ok
  end

  defp fs_root(config) do
    config
    |> Map.get(:fs_path, "tmp/cache/eirinchan")
    |> Path.expand(project_root())
  end

  defp fs_path(config, key) do
    hashed = :crypto.hash(:sha256, to_string(key)) |> Base.encode16(case: :lower)
    Path.join(fs_root(config), "#{Map.get(config, :prefix, "eirinchan_")}#{hashed}.cache")
  end

  defp normalize_config(%{cache: cache}), do: normalize_config(cache)

  defp normalize_config(config) when is_map(config) do
    Map.merge(
      %{
        enabled: false,
        driver: nil,
        prefix: "eirinchan_",
        ttl_seconds: 0,
        fs_path: "tmp/cache/eirinchan",
        redis: %{},
        memcached: %{}
      },
      config
    )
  end

  defp normalize_config(_config), do: normalize_config(%{})

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> @table
    end
  end

  defp expiry_timestamp(nil), do: nil
  defp expiry_timestamp(false), do: nil

  defp expiry_timestamp(ttl_seconds) when is_integer(ttl_seconds) and ttl_seconds > 0 do
    System.system_time(:second) + ttl_seconds
  end

  defp expiry_timestamp(_ttl_seconds), do: nil

  defp expired?(nil), do: false
  defp expired?(expires_at), do: expires_at <= System.system_time(:second)

  defp safe_binary_to_term(binary) do
    {:ok, :erlang.binary_to_term(binary)}
  rescue
    _ -> {:error, :invalid_cache_entry}
  end

  defp project_root do
    case Application.get_env(:eirinchan, :instance_config_path) do
      path when is_binary(path) -> Path.expand("..", Path.dirname(path))
      _ -> File.cwd!()
    end
  end
end
