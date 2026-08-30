# frozen_string_literal: true

Rails.application.routes.draw do
  # Sessão é singular: existe no máximo uma por navegador, e ela não tem
  # índice nem id na URL. `passwords` é plural e usa o token como parâmetro,
  # porque cada pedido de recuperação é um recurso próprio.
  resource :session
  resources :passwords, param: :token
  resources :credentials, only: [] do
    get :document, on: :member, to: "credential_documents#show"
  end

  resources :mission_bases, path: "bases", only: %i[index show] do
    resources :needs, only: %i[index], shallow: true
  end
  resources :projects, path: "obras", param: :code, only: %i[index show] do
    resources :progress_reports, only: %i[index show create], shallow: true
  end
  resources :campaigns, path: "campanhas", only: %i[index show]
  resources :needs, path: "necessidades", only: %i[index show] do
    resource :candidacy, only: %i[new create]
  end
  resource :search, only: :show

  namespace :admin do
    root to: "dashboard#show"
  end

  match "/404", to: "errors#not_found", via: :all, as: :error_not_found
  match "/403", to: "errors#forbidden", via: :all, as: :error_forbidden
  match "/422", to: "errors#unprocessable_entity", via: :all, as: :error_unprocessable_entity
  match "/500", to: "errors#internal_server_error", via: :all, as: :error_internal_server_error

  # Entrega de arquivo passa por autorização. Estes padrões são os mesmos que o
  # engine do Active Storage declara, e é justamente esse o mecanismo: as rotas
  # da aplicação são desenhadas ANTES das do engine, o roteador casa na ordem em
  # que foram declaradas, e o engine continua definindo os NOMES
  # (`rails_blob_path`, `rails_representation_url`) — que geram estas mesmas
  # URLs. Nada no resto do código muda de forma; muda quem atende.
  #
  # Sem `as:` de propósito: repetir um nome que o engine também declara levanta
  # `Invalid route name, already in use` no boot. Ver docs/photo-policy.md.
  scope ActiveStorage.routes_prefix do
    get "/blobs/redirect/:signed_id/*filename" => "authorized_blobs#show"
    get "/blobs/proxy/:signed_id/*filename" => "authorized_blobs#show"
    get "/blobs/:signed_id/*filename" => "authorized_blobs#show"

    get "/representations/redirect/:signed_blob_id/:variation_key/*filename" =>
          "authorized_representations#show"
    get "/representations/proxy/:signed_blob_id/:variation_key/*filename" =>
          "authorized_representations#show"
    get "/representations/:signed_blob_id/:variation_key/*filename" =>
          "authorized_representations#show"
  end

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
