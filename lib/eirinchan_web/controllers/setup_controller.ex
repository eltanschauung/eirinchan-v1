defmodule EirinchanWeb.SetupController do
  use EirinchanWeb, :controller

  alias Eirinchan.Installation

  def show(conn, _params) do
    if Installation.setup_required?() do
      render(conn, :show, params: Installation.setup_defaults(), errors: %{})
    else
      redirect(conn, to: ~p"/manage/login")
    end
  end

  def create(conn, params) do
    case Installation.run_setup(params) do
      {:ok, _admin} ->
        conn
        |> put_flash(:info, "Setup complete. Sign in with the admin account you just created.")
        |> redirect(to: ~p"/manage/login")

      {:error, %{errors: errors}} ->
        render(conn, :show,
          params: Map.merge(Installation.setup_defaults(), stringify(params)),
          errors: errors
        )

      {:error, reason} ->
        render(conn, :show,
          params: Map.merge(Installation.setup_defaults(), stringify(params)),
          errors: %{"setup" => Exception.message(reason)}
        )
    end
  end

  defp stringify(params) do
    Enum.into(params, %{}, fn {key, value} -> {to_string(key), value} end)
  end
end
