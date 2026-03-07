defmodule Eirinchan.Purge do
  @moduledoc false

  def purge_uri(uri, config, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, Map.get(config, :purge_timeout_seconds, 3) * 1_000)

    Enum.each(List.wrap(Map.get(config, :purge, [])), fn target ->
      {host, port, http_host} = normalize_target(target)

      if host && port do
        request =
          "PURGE #{uri} HTTP/1.1\r\nHost: #{http_host}\r\nUser-Agent: Eirinchan\r\nConnection: Close\r\n\r\n"

        with {:ok, socket} <-
               :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false], timeout),
             :ok <- :gen_tcp.send(socket, request) do
          :gen_tcp.close(socket)
        else
          _ -> :ok
        end
      end
    end)

    :ok
  end

  def purge_output_path(path, config, opts \\ []) do
    uri = output_uri(path, opts)

    if uri do
      purge_uri(uri, config, opts)

      if String.ends_with?(uri, "/index.html") do
        purge_uri(String.replace_suffix(uri, "index.html", ""), config, opts)
      end
    end

    :ok
  end

  def output_uri(path, opts \\ []) do
    root = Keyword.get(opts, :board_root, Application.get_env(:eirinchan, :build_output_root))

    if is_binary(root) and String.starts_with?(Path.expand(path), Path.expand(root)) do
      relative =
        Path.expand(path)
        |> Path.relative_to(Path.expand(root))
        |> String.replace("\\", "/")

      "/" <> relative
    end
  end

  defp normalize_target(%{host: host, port: port} = target) do
    {host, port, Map.get(target, :http_host, Map.get(target, "http_host", host))}
  end

  defp normalize_target(%{"host" => host, "port" => port} = target) do
    {host, port, Map.get(target, "http_host", host)}
  end

  defp normalize_target([host, port, http_host]), do: {host, port, http_host}
  defp normalize_target([host, port]), do: {host, port, host}
  defp normalize_target(_target), do: {nil, nil, nil}
end
