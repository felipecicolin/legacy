# frozen_string_literal: true

class SearchesController < ApplicationController
  # Tabela e grade mostram o MESMO conjunto: a escolha é de leitura, não de
  # conteúdo, e por isso ela mora num cookie em vez de na sessão — sobrevive ao
  # logout e não vale nada se vazar.
  VIEW_MODES = %w[table grid].freeze
  VIEW_COOKIE = :search_view

  allow_unauthenticated_access

  def show
    authorize_public_page

    render :show, locals: { search: search_query, view_mode: remembered_view_mode }
  end

  private

  # O termo é opcional: a tela abre com os filtros e sem termo, e é assim que
  # ela serve de listagem — "ver tudo" é a busca vazia.
  def search_query
    Search::Query.new(term: params[:query].presence, filters: Search::Filters.from(params), context: pundit_user)
  end

  # `request.query_parameters`, e não `params.expect(:view)`: o `expect`
  # LEVANTA quando a chave falta, e faltar é o caso normal — quem abre a busca
  # pela primeira vez não traz preferência na URL. O valor é imediatamente
  # restringido a `VIEW_MODES`, então não há parâmetro de massa a proteger.
  def remembered_view_mode
    chosen = request.query_parameters[:view].presence_in(VIEW_MODES)
    cookies.permanent[VIEW_COOKIE] = chosen if chosen

    chosen || cookies[VIEW_COOKIE].presence_in(VIEW_MODES) || VIEW_MODES.first
  end
end
