# Every route the process serves. format: false keeps /api/sum.json from
# matching /api/sum, and keeps the route template (the metrics label) plain.
Rails.application.routes.draw do
  scope format: false do
    get "/", to: "pages#index"
    get "/style.css", to: "pages#style"
    get "/app.js", to: "pages#script"

    get "/api/sum", to: "operations#sum"
    get "/api/sub", to: "operations#sub"
    get "/api/mul", to: "operations#mul"
    get "/api/div", to: "operations#div"

    get "/healthz", to: "health#show"
    get "/metrics", to: "metrics#show"

    # The same paths with any other method. GET routes answer HEAD as well.
    %w[/ /style.css /app.js /api/sum /api/sub /api/mul /api/div /healthz /metrics].each do |path|
      match path, to: "errors#method_not_allowed", via: :all
    end

    match "*path", to: "errors#not_found", via: :all
  end
end
