defmodule Eirinchan.Api do
  @moduledoc """
  Minimal 4chan-style JSON translation for thread/page/catalog artifacts.
  """

  def thread_json(summary) do
    %{
      posts: [
        thread_post(summary) | Enum.map(summary.replies, &reply_post(&1, summary.thread.id))
      ]
    }
  end

  def boards_json(boards) do
    %{
      boards:
        Enum.map(boards, fn board ->
          %{
            board: board.uri,
            title: board.title,
            ws_board: 1
          }
        end)
    }
  end

  def page_json(page_data) do
    %{
      threads: Enum.map(page_data.threads, &thread_json/1)
    }
  end

  def catalog_json(page_data_list, opts \\ []) do
    threads_page? = Keyword.get(opts, :threads_page, false)

    Enum.with_index(page_data_list)
    |> Enum.map(fn {page_data, page_index} ->
      %{
        page: page_index,
        threads: Enum.map(page_data.threads, &catalog_thread(&1, threads_page?))
      }
    end)
  end

  defp catalog_thread(summary, true) do
    %{
      no: summary.thread.id,
      last_modified: unix(summary.last_modified)
    }
  end

  defp catalog_thread(summary, false) do
    thread_post(summary)
  end

  defp thread_post(summary) do
    summary.thread
    |> base_post(0)
    |> maybe_put(:sub, summary.thread.subject)
    |> maybe_put(:com, summary.thread.body)
    |> maybe_put(:name, summary.thread.name)
    |> Map.put(:time, unix(summary.thread.inserted_at))
    |> Map.put(:replies, summary.reply_count)
    |> Map.put(:images, summary.image_count)
    |> maybe_put(:semantic_url, summary.thread.slug)
    |> maybe_put(:omitted_posts, positive_or_nil(summary.omitted_posts))
    |> maybe_put(:omitted_images, positive_or_nil(summary.omitted_images))
    |> Map.put(:last_modified, unix(summary.last_modified))
  end

  defp reply_post(post, thread_id) do
    post
    |> base_post(thread_id)
    |> maybe_put(:sub, post.subject)
    |> maybe_put(:com, post.body)
    |> maybe_put(:name, post.name)
    |> Map.put(:time, unix(post.inserted_at))
  end

  defp base_post(post, resto) do
    %{
      no: post.id,
      resto: resto
    }
  end

  defp unix(%DateTime{} = dt), do: DateTime.to_unix(dt)

  defp unix(%NaiveDateTime{} = dt),
    do: dt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp positive_or_nil(value) when is_integer(value) and value > 0, do: value
  defp positive_or_nil(_value), do: nil
end
