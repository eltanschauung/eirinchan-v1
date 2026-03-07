defmodule Eirinchan.Moderation.ModBoardAccess do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mod_board_accesses" do
    belongs_to :mod_user, Eirinchan.Moderation.ModUser
    belongs_to :board, Eirinchan.Boards.BoardRecord

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(access, attrs) do
    access
    |> cast(attrs, [:mod_user_id, :board_id])
    |> validate_required([:mod_user_id, :board_id])
    |> foreign_key_constraint(:mod_user_id)
    |> foreign_key_constraint(:board_id)
    |> unique_constraint([:mod_user_id, :board_id],
      name: :mod_board_accesses_mod_user_id_board_id_index
    )
  end
end
