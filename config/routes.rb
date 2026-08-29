# frozen_string_literal: true

Rails.application.routes.draw do
  # Sessão é singular: existe no máximo uma por navegador, e ela não tem
  # índice nem id na URL. `passwords` é plural e usa o token como parâmetro,
  # porque cada pedido de recuperação é um recurso próprio.
  resource :session
  resources :passwords, param: :token

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Espaço reservado até #8 (shell de layout) e #57 (rotas e controllers). O
  # que não pode sumir é a rota existir: `after_authentication_url` cai aqui
  # quando o login não tinha destino guardado.
  root "home#show"
end
