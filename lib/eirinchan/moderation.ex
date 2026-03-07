defmodule Eirinchan.Moderation do
  @moduledoc """
  Minimal moderator user store and session authentication.
  """

  import Ecto.Query, only: [from: 2]

  alias Eirinchan.Moderation.ModUser
  alias Eirinchan.Repo

  @spec create_user(map(), keyword()) :: {:ok, ModUser.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    %ModUser{}
    |> ModUser.create_changeset(attrs)
    |> repo.insert()
  end

  @spec get_user(integer(), keyword()) :: ModUser.t() | nil
  def get_user(id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    repo.get(ModUser, id)
  end

  @spec list_users(keyword()) :: [ModUser.t()]
  def list_users(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    repo.all(from user in ModUser, order_by: [asc: user.username])
  end

  @spec authenticate(String.t(), String.t(), keyword()) ::
          {:ok, ModUser.t()} | {:error, :invalid_credentials}
  def authenticate(username, password, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    case repo.get_by(ModUser, username: String.trim(username || "")) do
      nil ->
        {:error, :invalid_credentials}

      %ModUser{} = user ->
        if ModUser.verify_password(user, password) do
          {:ok, touch_login(user, repo)}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  defp touch_login(user, repo) do
    {:ok, updated} =
      user
      |> ModUser.login_changeset(%{
        last_login_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      })
      |> repo.update()

    updated
  end
end
