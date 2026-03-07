defmodule EirinchanWeb.IpManagementJSON do
  def show(%{ip: ip, posts: posts, notes: notes}) do
    %{
      data: %{
        ip: ip,
        posts: Enum.map(posts, &post_data/1),
        notes: Enum.map(notes, &note_data/1)
      }
    }
  end

  def note(%{note: note}) do
    %{data: note_data(note)}
  end

  defp post_data(post) do
    %{
      id: post.id,
      board_id: post.board_id,
      thread_id: post.thread_id,
      ip_subnet: post.ip_subnet,
      subject: post.subject,
      body: post.body,
      inserted_at: post.inserted_at
    }
  end

  defp note_data(note) do
    %{
      id: note.id,
      ip_subnet: note.ip_subnet,
      body: note.body,
      board_id: note.board_id,
      mod_user_id: note.mod_user_id,
      inserted_at: note.inserted_at
    }
  end
end
