defmodule Eirinchan.PurgeTest do
  use ExUnit.Case, async: false

  alias Eirinchan.Purge

  test "purge_uri sends a PURGE request to configured endpoints" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listener)
    parent = self()

    spawn(fn ->
      {:ok, socket} = :gen_tcp.accept(listener)
      {:ok, request} = :gen_tcp.recv(socket, 0, 1_000)
      send(parent, {:purge_request, request})
      :gen_tcp.close(socket)
    end)

    assert :ok =
             Purge.purge_uri("/tea/index.html", %{purge: [["127.0.0.1", port, "example.test"]]})

    assert_receive {:purge_request, request}, 1_000
    assert request =~ "PURGE /tea/index.html HTTP/1.1"
    assert request =~ "Host: example.test"

    :gen_tcp.close(listener)
  end
end
