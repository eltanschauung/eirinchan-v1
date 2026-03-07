defmodule EirinchanWeb.Router do
  use EirinchanWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EirinchanWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/manage", EirinchanWeb do
    pipe_through :api

    get "/boards", BoardManagementController, :index
    post "/boards", BoardManagementController, :create
    get "/boards/:uri", BoardManagementController, :show
    patch "/boards/:uri", BoardManagementController, :update
    delete "/boards/:uri", BoardManagementController, :delete
    get "/boards/:uri/threads/:thread_id", ThreadManagementController, :show
    patch "/boards/:uri/threads/:thread_id", ThreadManagementController, :update
  end

  scope "/api", EirinchanWeb do
    pipe_through :api

    get "/boards.json", ApiController, :boards
    get "/:board/catalog.json", ApiController, :catalog
    get "/:board/threads.json", ApiController, :threads
    get "/:board/res/:thread_id", ApiController, :thread
    get "/:board/pages/:page_num", ApiController, :page
  end

  scope "/", EirinchanWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/:board/catalog.html", BoardController, :catalog
    get "/:board/:page_num_html", BoardController, :show_page
    get "/:board", BoardController, :show
    post "/:board/post", PostController, :create
    get "/:board/res/:thread_id", ThreadController, :show
  end
end
