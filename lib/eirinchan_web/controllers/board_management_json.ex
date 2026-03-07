defmodule EirinchanWeb.BoardManagementJSON do
  def index(%{boards: boards}) do
    %{data: Enum.map(boards, &board_data/1)}
  end

  def show(%{board: board}) do
    %{data: board_data(board)}
  end

  defp board_data(board) do
    %{
      uri: board.uri,
      title: board.title,
      subtitle: board.subtitle,
      config_overrides: board.config_overrides
    }
  end
end
