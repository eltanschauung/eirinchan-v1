defmodule Eirinchan.BuildQueue do
  @moduledoc """
  Minimal queue for deferred board/thread rebuild jobs.
  """

  import Ecto.Query, only: [from: 2]

  alias Eirinchan.BuildQueue.Job
  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Repo

  def enqueue_thread(%BoardRecord{} = board, thread_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    %Job{}
    |> Job.changeset(%{board_id: board.id, kind: "thread", thread_id: thread_id})
    |> repo.insert()
  end

  def enqueue_indexes(%BoardRecord{} = board, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    %Job{}
    |> Job.changeset(%{board_id: board.id, kind: "indexes"})
    |> repo.insert()
  end

  def list_pending(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    board_id = Keyword.get(opts, :board_id)

    query =
      from job in Job,
        where: job.status == "pending",
        order_by: [asc: job.inserted_at, asc: job.id]

    query =
      case board_id do
        nil -> query
        _ -> from job in query, where: job.board_id == ^board_id
      end

    repo.all(query)
  end

  def mark_done(%Job{} = job, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    job |> Job.done_changeset() |> repo.update()
  end
end
