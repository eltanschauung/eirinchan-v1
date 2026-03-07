defmodule Eirinchan.Moderation do
  @moduledoc """
  Minimal moderator user store and session authentication.
  """

  import Ecto.Query, only: [from: 2]

  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Moderation.{IpNote, ModBoardAccess, ModUser}
  alias Eirinchan.Posts.Post
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

  @spec grant_board_access(ModUser.t(), BoardRecord.t(), keyword()) ::
          {:ok, ModBoardAccess.t()} | {:error, Ecto.Changeset.t()}
  def grant_board_access(%ModUser{} = user, %BoardRecord{} = board, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    %ModBoardAccess{}
    |> ModBoardAccess.changeset(%{mod_user_id: user.id, board_id: board.id})
    |> repo.insert(
      on_conflict: :nothing,
      conflict_target: [:mod_user_id, :board_id]
    )
  end

  @spec list_accessible_boards(ModUser.t() | nil, keyword()) :: [BoardRecord.t()]
  def list_accessible_boards(user), do: list_accessible_boards(user, [])

  def list_accessible_boards(nil, _opts), do: []

  def list_accessible_boards(%ModUser{role: "admin"}, opts) do
    Eirinchan.Boards.list_boards(opts)
  end

  def list_accessible_boards(%ModUser{} = user, opts) do
    repo = Keyword.get(opts, :repo, Repo)

    repo.all(
      from board in BoardRecord,
        join: access in ModBoardAccess,
        on: access.board_id == board.id,
        where: access.mod_user_id == ^user.id,
        order_by: [asc: board.uri]
    )
  end

  @spec board_access?(ModUser.t() | nil, BoardRecord.t(), keyword()) :: boolean()
  def board_access?(user, board), do: board_access?(user, board, [])

  def board_access?(nil, _board, _opts), do: false
  def board_access?(%ModUser{role: "admin"}, _board, _opts), do: true

  def board_access?(%ModUser{} = user, %BoardRecord{} = board, opts) do
    repo = Keyword.get(opts, :repo, Repo)

    repo.exists?(
      from access in ModBoardAccess,
        where: access.mod_user_id == ^user.id and access.board_id == ^board.id
    )
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

  @spec add_ip_note(String.t(), map(), keyword()) ::
          {:ok, IpNote.t()} | {:error, Ecto.Changeset.t()}
  def add_ip_note(ip_subnet, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    %IpNote{}
    |> IpNote.changeset(
      attrs
      |> Enum.into(%{})
      |> Map.put(:ip_subnet, normalize_ip(ip_subnet))
    )
    |> repo.insert()
  end

  @spec list_ip_notes(String.t(), keyword()) :: [IpNote.t()]
  def list_ip_notes(ip_subnet, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    board_id = Keyword.get(opts, :board_id)

    query =
      from note in IpNote,
        where: note.ip_subnet == ^normalize_ip(ip_subnet),
        order_by: [asc: note.inserted_at],
        preload: [:board, :mod_user]

    query =
      if board_id do
        from note in query, where: is_nil(note.board_id) or note.board_id == ^board_id
      else
        query
      end

    repo.all(query)
  end

  @spec list_ip_posts(String.t(), keyword()) :: [Post.t()]
  def list_ip_posts(ip_subnet, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    board_ids = Keyword.get(opts, :board_ids)

    query =
      from post in Post,
        where: post.ip_subnet == ^normalize_ip(ip_subnet),
        order_by: [desc: post.inserted_at, desc: post.id]

    query =
      case board_ids do
        ids when is_list(ids) -> from post in query, where: post.board_id in ^ids
        _ -> query
      end

    repo.all(query)
  end

  defp normalize_ip(ip) when is_binary(ip), do: String.trim(ip)

  defp normalize_ip({a, b, c, d}), do: Enum.join([a, b, c, d], ".")

  defp normalize_ip({a, b, c, d, e, f, g, h}) do
    [a, b, c, d, e, f, g, h]
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.join(":")
  end

  defp normalize_ip(_ip), do: nil
end
