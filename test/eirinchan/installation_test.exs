defmodule Eirinchan.InstallationTest do
  use ExUnit.Case, async: false

  alias Eirinchan.Installation

  setup do
    original = Application.get_env(:eirinchan, :installation_config_path)

    path =
      Path.join(System.tmp_dir!(), "eirinchan-install-#{System.unique_integer([:positive])}.json")

    Application.put_env(:eirinchan, :installation_config_path, path)

    on_exit(fn ->
      Application.put_env(:eirinchan, :installation_config_path, original)
      File.rm(path)
    end)

    :ok
  end

  test "persisted_repo_config round-trips stored settings" do
    assert :ok =
             Installation.persist_repo_config(
               hostname: "db.local",
               port: 5544,
               database: "eirinchan_prod",
               username: "chan",
               password: "secret"
             )

    assert Installation.persisted_repo_config()[:hostname] == "db.local"
    assert Installation.persisted_repo_config()[:port] == 5544
    assert Installation.persisted_repo_config()[:database] == "eirinchan_prod"
  end
end
