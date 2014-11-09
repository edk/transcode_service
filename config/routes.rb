Rails.application.routes.draw do
  resources :transcode_jobs, except: [:new, :edit]
end
