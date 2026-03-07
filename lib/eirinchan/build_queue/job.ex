defmodule Eirinchan.BuildQueue.Job do
  use Ecto.Schema
  import Ecto.Changeset

  schema "build_jobs" do
    field :kind, :string
    field :thread_id, :integer
    field :status, :string, default: "pending"
    field :finished_at, :utc_datetime_usec
    field :driver_meta, :map, virtual: true

    belongs_to :board, Eirinchan.Boards.BoardRecord

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:board_id, :kind, :thread_id, :status, :finished_at])
    |> validate_required([:board_id, :kind])
    |> validate_inclusion(:kind, ["thread", "indexes"])
    |> foreign_key_constraint(:board_id)
  end

  def done_changeset(job) do
    change(job, status: "done", finished_at: DateTime.utc_now() |> DateTime.truncate(:microsecond))
  end
end
