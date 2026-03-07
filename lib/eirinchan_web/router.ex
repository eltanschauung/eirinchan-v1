defmodule EirinchanWeb.Router do
  use EirinchanWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug EirinchanWeb.Plugs.FetchCurrentModerator
    plug :fetch_live_flash
    plug :put_root_layout, html: {EirinchanWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug EirinchanWeb.Plugs.FetchCurrentModerator
  end

  pipeline :manage_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug EirinchanWeb.Plugs.FetchCurrentModerator
    plug EirinchanWeb.Plugs.RequireModerator
  end

  pipeline :manage_janitor do
    plug :accepts, ["json"]
    plug :fetch_session
    plug EirinchanWeb.Plugs.FetchCurrentModerator
    plug EirinchanWeb.Plugs.RequireModerator
    plug EirinchanWeb.Plugs.RequireModeratorRole, role: "janitor"
  end

  pipeline :manage_mod do
    plug :accepts, ["json"]
    plug :fetch_session
    plug EirinchanWeb.Plugs.FetchCurrentModerator
    plug EirinchanWeb.Plugs.RequireModerator
    plug EirinchanWeb.Plugs.RequireModeratorRole, role: "mod"
    plug EirinchanWeb.Plugs.RequireSecureManageToken
  end

  pipeline :manage_admin do
    plug :accepts, ["json"]
    plug :fetch_session
    plug EirinchanWeb.Plugs.FetchCurrentModerator
    plug EirinchanWeb.Plugs.RequireModerator
    plug EirinchanWeb.Plugs.RequireModeratorRole, role: "admin"
    plug EirinchanWeb.Plugs.RequireSecureManageToken
  end

  scope "/manage", EirinchanWeb do
    pipe_through :browser

    get "/login", ManagePageController, :login
    post "/login/browser", ManagePageController, :create_session
    get "/", ManagePageController, :dashboard
    post "/boards/browser", ManagePageController, :create_board
    delete "/logout/browser", ManagePageController, :delete_session
  end

  scope "/", EirinchanWeb do
    pipe_through :browser

    get "/setup", SetupController, :show
    post "/setup", SetupController, :create
  end

  scope "/manage", EirinchanWeb do
    pipe_through :api

    post "/login", ManageSessionController, :create
    get "/session", ManageSessionController, :show
    get "/secure-token", ManageSessionController, :secure_token
    delete "/logout", ManageSessionController, :delete
  end

  scope "/manage", EirinchanWeb do
    pipe_through :manage_api

    get "/dashboard", ModDashboardController, :show
    get "/recent-posts", ModDashboardController, :recent
    get "/boards/:uri/threads/:thread_id", ThreadManagementController, :show
    get "/boards/:uri/bans", BanManagementController, :index
    get "/boards/:uri/ban-appeals", BanAppealManagementController, :index
    get "/boards/:uri/reports", ReportManagementController, :index
    get "/feedback", FeedbackManagementController, :index
    get "/boards", BoardManagementController, :index
    get "/boards/:uri", BoardManagementController, :show
  end

  scope "/manage", EirinchanWeb do
    pipe_through :manage_mod

    patch "/feedback/:id/read", FeedbackManagementController, :mark_read
    post "/feedback/:id/comments", FeedbackManagementController, :create_comment
    delete "/feedback/:id", FeedbackManagementController, :delete
    patch "/boards/:uri/threads/:thread_id", ThreadManagementController, :update
    post "/boards/:uri/bans", BanManagementController, :create
    patch "/boards/:uri/bans/:id", BanManagementController, :update
    patch "/boards/:uri/ban-appeals/:id", BanAppealManagementController, :update
    delete "/boards/:uri/reports/post/:post_id", ReportManagementController, :delete_post
    delete "/boards/:uri/reports/:id", ReportManagementController, :delete
  end

  scope "/manage", EirinchanWeb do
    pipe_through :manage_admin

    post "/boards", BoardManagementController, :create
    patch "/boards/:uri", BoardManagementController, :update
    delete "/boards/:uri", BoardManagementController, :delete
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
    get "/feedback", FeedbackController, :show
    post "/feedback", FeedbackController, :create
    get "/:board/thumb/:filename", UploadedFileController, :show_thumb
    get "/:board/src/:filename", UploadedFileController, :show
    get "/:board/catalog.html", BoardController, :catalog
    get "/:board/:page_num_html", BoardController, :show_page
    get "/:board", BoardController, :show
    post "/:board/post", PostController, :create
    get "/:board/res/:thread_id", ThreadController, :show
  end
end
