defmodule Eirinchan.Runtime.RequestContext do
  @moduledoc """
  Request-scoped runtime state that replaces vichan's mutable globals.
  """

  @enforce_keys [:config]
  defstruct board: nil, config: %{}

  @type t :: %__MODULE__{
          board: Eirinchan.Boards.Board.t() | nil,
          config: map()
        }
end
