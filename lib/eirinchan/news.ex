defmodule Eirinchan.News do
  @moduledoc """
  Simple public news/noticeboard entries managed from the browser moderation UI.
  """

  import Ecto.Query, only: [from: 2]

  alias Eirinchan.News.Entry
  alias Eirinchan.Repo

  def list_entries(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    limit = Keyword.get(opts, :limit)

    query =
      from entry in Entry,
        order_by: [desc: entry.inserted_at, desc: entry.id],
        preload: [:mod_user]

    query =
      if is_integer(limit) and limit > 0 do
        from entry in query, limit: ^limit
      else
        query
      end

    repo.all(query)
  end

  def get_entry(id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    case repo.get(Entry, id) do
      nil -> nil
      entry -> repo.preload(entry, :mod_user)
    end
  end

  def create_entry(attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    %Entry{}
    |> Entry.changeset(attrs)
    |> repo.insert()
  end

  def update_entry(%Entry{} = entry, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    entry
    |> Entry.changeset(attrs)
    |> repo.update()
  end

  def delete_entry(%Entry{} = entry, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    repo.delete(entry)
  end
end
