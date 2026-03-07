defmodule Eirinchan.Settings do
  @moduledoc """
  Persists instance-level runtime overrides for the browser admin config editor.
  """

  alias Eirinchan.Runtime.Config

  @spec current_instance_config() :: map()
  def current_instance_config do
    persisted_instance_config() || %{}
  end

  @spec persisted_instance_config() :: map() | nil
  def persisted_instance_config do
    path = config_path()

    with true <- is_binary(path) and File.exists?(path),
         {:ok, body} <- File.read(path),
         {:ok, decoded} <- Jason.decode(body),
         true <- is_map(decoded) do
      Config.normalize_override_keys(decoded)
    else
      _ -> nil
    end
  end

  @spec update_instance_config_from_json(binary()) :: {:ok, map()} | {:error, :invalid_json}
  def update_instance_config_from_json(raw_json) when is_binary(raw_json) do
    with {:ok, decoded} <- Jason.decode(raw_json),
         true <- is_map(decoded),
         normalized <- Config.normalize_override_keys(decoded),
         :ok <- persist_instance_config(normalized) do
      {:ok, normalized}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      false -> {:error, :invalid_json}
      {:error, _reason} = error -> error
    end
  end

  @spec persist_instance_config(map()) :: :ok | {:error, term()}
  def persist_instance_config(overrides) when is_map(overrides) do
    path = config_path()

    path
    |> Path.dirname()
    |> File.mkdir_p!()

    overrides
    |> stringify_keys()
    |> Jason.encode_to_iodata!(pretty: true)
    |> then(&File.write(path, &1))
  end

  @spec config_path() :: binary() | nil
  def config_path do
    Application.get_env(:eirinchan, :instance_config_path)
  end

  @spec encode_for_edit(map()) :: binary()
  def encode_for_edit(overrides) when is_map(overrides) do
    overrides
    |> stringify_keys()
    |> Jason.encode!(pretty: true)
  end

  defp stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {to_string(key), stringify_keys(nested_value)}
    end)
  end

  defp stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  defp stringify_keys(value), do: value
end
