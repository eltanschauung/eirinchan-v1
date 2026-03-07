defmodule Eirinchan.CustomPages do
  @moduledoc """
  Global custom pages such as rules/help/faq.
  """

  import Ecto.Query, only: [from: 2]

  alias Eirinchan.CustomPages.Page
  alias Eirinchan.Repo

  def list_pages(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    repo.all(
      from page in Page,
        order_by: [asc: page.slug],
        preload: [:mod_user]
    )
  end

  def get_page_by_slug(slug, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    case repo.get_by(Page, slug: to_string(slug)) do
      nil -> nil
      page -> repo.preload(page, :mod_user)
    end
  end

  def create_page(attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    %Page{}
    |> Page.changeset(attrs)
    |> repo.insert()
  end

  def update_page(%Page{} = page, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    page
    |> Page.changeset(attrs)
    |> repo.update()
  end

  def delete_page(%Page{} = page, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    repo.delete(page)
  end
end
