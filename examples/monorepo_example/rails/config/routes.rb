Rails.application.routes.draw do
  mount GoodJob::Engine => "/good_job" if defined?(GoodJob::Engine)
  
  root "home#index"
  
  get "/health", to: proc { |env| [200, {}, ["OK"]] }
  
  get "/stats", to: "home#stats", as: :stats
  get "/jobs", to: "home#jobs", as: :jobs
  
  post "/jobs/enqueue", to: "jobs#enqueue", as: :jobs_enqueue
end

