# frozen_string_literal: true

class CandidaciesController < ApplicationController
  def new
    render_candidacy_form(build_candidacy)
  end

  # A vaga pode ter acabado entre a renderização do formulário e o envio: é o
  # caso de corrida do abatimento chegando à interface. A validação de `Need`
  # recusa, e a recusa vira erro de formulário — nunca 500. Ver
  # docs/mobilization.md.
  def create
    candidacy = build_candidacy(candidacy_params)
    return render_candidacy_form(candidacy, status: :unprocessable_content) unless candidacy.save

    redirect_to need_path(candidacy.need), notice: t(".submitted")
  end

  private

  def build_candidacy(attributes = {})
    need = policy_scope(Need).find(params.expect(:need_id))
    need.candidacies.new(profile: Current.user.profile, **attributes).tap { |record| authorize record }
  end

  def render_candidacy_form(candidacy, status: :ok)
    render :new, status: status, locals: { candidacy: candidacy }
  end

  def candidacy_params
    params.expect(candidacy: [:motivation, { documents: [] }])
  end
end
