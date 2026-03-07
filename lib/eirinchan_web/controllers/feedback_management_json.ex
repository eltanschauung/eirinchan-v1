defmodule EirinchanWeb.FeedbackManagementJSON do
  def index(%{feedback: feedback, unread_count: unread_count}) do
    %{data: Enum.map(feedback, &feedback_data/1), unread_count: unread_count}
  end

  def show(%{feedback: feedback}) do
    %{data: feedback_data(feedback)}
  end

  defp feedback_data(feedback) do
    %{
      id: feedback.id,
      name: feedback.name,
      email: feedback.email,
      body: feedback.body,
      ip_subnet: feedback.ip_subnet,
      read_at: feedback.read_at,
      comments: Enum.map(feedback.comments || [], &comment_data/1)
    }
  end

  defp comment_data(comment) do
    %{
      id: comment.id,
      body: comment.body,
      inserted_at: comment.inserted_at
    }
  end
end
