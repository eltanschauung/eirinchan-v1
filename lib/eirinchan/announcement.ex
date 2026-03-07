defmodule Eirinchan.Announcement do
  @moduledoc """
  Singleton sitewide announcement/blotter entry.
  """

  import Ecto.Query, only: [from: 2]

  alias Eirinchan.Announcement.Entry
  alias Eirinchan.Repo

  def current(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    repo.one(
      from entry in Entry,
        order_by: [desc: entry.updated_at, desc: entry.id],
        limit: 1,
        preload: [:mod_user]
    )
  end

  def upsert(attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    case current(repo: repo) do
      nil ->
        %Entry{}
        |> Entry.changeset(attrs)
        |> repo.insert()

      %Entry{} = entry ->
        entry
        |> Entry.changeset(attrs)
        |> repo.update()
    end
  end

  def delete_current(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    case current(repo: repo) do
      nil -> {:ok, nil}
      %Entry{} = entry -> repo.delete(entry)
    end
  end
end
