Rails.application.routes.draw do
  namespace :api do
    resources :transcode_jobs, except: [:new, :edit] do
      get :ping, :on => :collection
    end
  end
end
