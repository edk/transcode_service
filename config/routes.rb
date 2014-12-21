Rails.application.routes.draw do
  namespace :api do
    resources :transcode_jobs, except: [:new, :edit]
  end
end
