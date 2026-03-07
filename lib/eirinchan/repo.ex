defmodule Eirinchan.Repo do
  use Ecto.Repo,
    otp_app: :eirinchan,
    adapter: Ecto.Adapters.Postgres
end
