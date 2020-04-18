Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  
  authenticate :admin_user do
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
  
  namespace :api do
    get '/home/index' => 'home#index'
  end
  root 'home#index'

  %w( 404 422 500 ).each do |code|
    get code, :to => "errors#show", :code => code
  end

  get 'health_check', to: 'home#health_check'
end
