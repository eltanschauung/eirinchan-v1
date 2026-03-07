defmodule Eirinchan.Posts do
  @moduledoc """
  Minimal posting pipeline for OP and reply creation.
  """

  import Ecto.Query, only: [from: 2]

  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Posts.Post
  alias Eirinchan.Repo

  @spec create_post(BoardRecord.t(), map(), keyword()) ::
          {:ok, Post.t()} | {:error, :thread_not_found} | {:error, Ecto.Changeset.t()}
  def create_post(%BoardRecord{} = board, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    thread_param = blank_to_nil(Map.get(attrs, "thread") || Map.get(attrs, :thread))

    if thread_param do
      create_reply(board, thread_param, attrs, repo)
    else
      create_thread(board, attrs, repo)
    end
  end

  @spec list_threads(BoardRecord.t(), keyword()) :: [Post.t()]
  def list_threads(%BoardRecord{} = board, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    repo.all(
      from post in Post,
        where: post.board_id == ^board.id and is_nil(post.thread_id),
        order_by: [desc: post.inserted_at]
    )
  end

  @spec get_thread(BoardRecord.t(), String.t() | integer(), keyword()) ::
          {:ok, [Post.t()]} | {:error, :not_found}
  def get_thread(%BoardRecord{} = board, thread_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    normalized_thread_id = normalize_thread_id(thread_id)

    case repo.one(
           from post in Post,
             where:
               post.id == ^normalized_thread_id and post.board_id == ^board.id and
                 is_nil(post.thread_id)
         ) do
      nil ->
        {:error, :not_found}

      thread ->
        replies =
          repo.all(
            from post in Post,
              where: post.board_id == ^board.id and post.thread_id == ^thread.id,
              order_by: [asc: post.inserted_at]
          )

        {:ok, [thread | replies]}
    end
  end

  defp create_thread(board, attrs, repo) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put("board_id", board.id)
      |> Map.put("thread_id", nil)

    %Post{}
    |> Post.create_changeset(attrs)
    |> repo.insert()
  end

  defp create_reply(board, thread_id, attrs, repo) do
    thread_id = normalize_thread_id(thread_id)

    case repo.one(
           from post in Post,
             where:
               post.id == ^thread_id and post.board_id == ^board.id and is_nil(post.thread_id)
         ) do
      nil ->
        {:error, :thread_not_found}

      thread ->
        attrs =
          attrs
          |> normalize_attrs()
          |> Map.put("board_id", board.id)
          |> Map.put("thread_id", thread.id)

        %Post{}
        |> Post.create_changeset(attrs)
        |> repo.insert()
    end
  end

  defp normalize_attrs(attrs) do
    attrs
    |> Enum.into(%{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      pair -> pair
    end)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp normalize_thread_id(value) when is_integer(value), do: value

  defp normalize_thread_id(value) when is_binary(value) do
    value
    |> String.replace_suffix(".html", "")
    |> String.trim()
    |> String.to_integer()
  end
end
