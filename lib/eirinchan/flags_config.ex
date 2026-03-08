defmodule Eirinchan.FlagsConfig do
  @moduledoc """
  Instance-configurable flag settings mirroring the relevant vichan config.php knobs.
  """

  alias Eirinchan.Runtime.Config
  alias Eirinchan.Settings

  @flag_keys [
    :country_flags,
    :allow_no_country,
    :country_flags_condensed,
    :country_flags_condensed_css,
    :display_flags,
    :uri_flags,
    :flag_style,
    :user_flag,
    :multiple_flags,
    :default_user_flag,
    :user_flags
  ]

  @boolean_keys [:country_flags, :allow_no_country, :country_flags_condensed, :display_flags, :user_flag, :multiple_flags]

  @spec form_values() :: map()
  def form_values do
    config = current_config()

    %{
      country_flags: config.country_flags,
      allow_no_country: config.allow_no_country,
      country_flags_condensed: Map.get(config, :country_flags_condensed, false),
      country_flags_condensed_css: Map.get(config, :country_flags_condensed_css, ""),
      display_flags: Map.get(config, :display_flags, true),
      uri_flags: Map.get(config, :uri_flags, ""),
      flag_style: Map.get(config, :flag_style, ""),
      user_flag: config.user_flag,
      multiple_flags: config.multiple_flags,
      default_user_flag: config.default_user_flag,
      user_flags_json: encode_user_flags(Map.get(config, :user_flags, %{}))
    }
  end

  @spec update(map()) :: {:ok, map()} | {:error, :invalid_json}
  def update(params) when is_map(params) do
    with {:ok, user_flags} <- parse_user_flags(Map.get(params, "user_flags_json", "")) do
      overrides =
        @flag_keys
        |> Enum.reduce(%{}, fn key, acc ->
          Map.put(acc, key, normalized_value(key, params, user_flags))
        end)

      config =
        Settings.current_instance_config()
        |> Map.merge(overrides)

      case Settings.persist_instance_config(config) do
        :ok -> {:ok, overrides}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp current_config do
    Settings.current_instance_config()
    |> then(&Config.compose(nil, &1, %{}))
  end

  defp parse_user_flags(raw_json) when is_binary(raw_json) do
    trimmed = String.trim(raw_json)

    if trimmed == "" do
      {:ok, %{}}
    else
      with {:ok, decoded} <- Jason.decode(trimmed),
           true <- is_map(decoded) do
        {:ok, normalize_user_flags(decoded)}
      else
        {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
        false -> {:error, :invalid_json}
        _ -> {:error, :invalid_json}
      end
    end
  end

  defp normalize_user_flags(flags) do
    flags
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      normalized_key = key |> to_string() |> String.trim()
      normalized_value = value |> to_string() |> String.trim()

      if normalized_key == "" or normalized_value == "" do
        acc
      else
        Map.put(acc, normalized_key, normalized_value)
      end
    end)
  end

  defp encode_user_flags(flags) when is_map(flags), do: Jason.encode!(flags, pretty: true)

  defp normalized_value(:user_flags, _params, user_flags), do: user_flags

  defp normalized_value(key, params, _user_flags) when key in @boolean_keys do
    Map.get(params, Atom.to_string(key), "false") in ["true", "1", "on"]
  end

  defp normalized_value(key, params, _user_flags) do
    params
    |> Map.get(Atom.to_string(key), default_value(key))
    |> to_string()
    |> String.trim()
  end

  defp default_value(key) do
    Config.default_config()
    |> Map.get(key)
    |> to_string()
  end
end
