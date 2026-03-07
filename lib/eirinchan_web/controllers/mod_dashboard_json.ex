defmodule EirinchanWeb.ModDashboardJSON do
  def show(%{data: data}), do: %{data: data}

  def recent(%{posts: posts}) do
    %{
      data:
        Enum.map(posts, fn post ->
          %{
            id: post.id,
            board_id: post.board_id,
            thread_id: post.thread_id,
            subject: post.subject,
            body: post.body,
            inserted_at: post.inserted_at
          }
        end)
    }
  end
end
