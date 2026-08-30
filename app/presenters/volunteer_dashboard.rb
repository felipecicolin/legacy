# frozen_string_literal: true

# A visão do voluntário: o que ele pode servir, o que já pediu, e o que falta
# nele para poder pedir.
#
# É a tela que fecha o produto — sem ela a plataforma mostra obras e não conecta
# ninguém. Ver docs/mobilization.md.
class VolunteerDashboard
  # O perfil é obrigatório: um painel de voluntário sem pessoa não tem o que
  # responder, e um `nil` aqui viraria quatro guardas espalhadas pelos métodos.
  # Quem ainda não tem perfil é decidido no controller, uma vez.
  def initialize(profile, context)
    @profile = profile
    @context = context
  end

  # A granularidade da localização é decidida pelo contexto, e a view precisa
  # dele para perguntar — não para decidir nada por conta própria.
  delegate :visibility, to: :@context

  # O casamento por habilidade, e ele passa pelo `visible_to` do próprio
  # `matching`: necessidade que o voluntário não alcança não aparece nem como
  # negada.
  def matched_needs
    Need.matching(@profile).visible_to(@context.visibility).includes(:mission_base, :skill)
  end

  # Sem habilidade cadastrada não há casamento possível, e a tela precisa dizer
  # isso em vez de mostrar uma lista vazia que se lê como "não há o que fazer".
  def skills_registered? = @profile.profile_skills.any?

  def open_needs(filters)
    filters.apply_to_needs(Need.visible_to(@context.visibility).need_status_open)
           .includes(:mission_base, :skill).by_priority
  end

  def candidacies
    @profile.candidacies.includes(need: :mission_base).order(created_at: :desc)
  end

  def assignments
    Assignment.where(candidacy: candidacies).includes(need: :mission_base).order(starts_on: :desc)
  end

  # Envio é logística, e a lista é a dos que ainda vão partir. Só os que vão
  # para base ALCANÇÁVEL: o envio não tem nível próprio, e listar um para uma
  # base confidencial contaria que ela existe pelo destino da viagem.
  #
  # Sem requisito de documento: não há `TravelDocument` neste domínio, por
  # decisão registrada em docs/mobilization.md.
  def open_deployments
    Deployment.deployment_status_open.upcoming
              .where(mission_base: MissionBase.visible_to(@context.visibility))
              .includes(:mission_base)
  end

  def engagements
    @profile.volunteer_engagements.includes(:volunteer_group).order(started_on: :desc)
  end

  # O que trava a candidatura tem de estar visível ANTES da tentativa. Quem tem
  # credencial pendente precisa saber que é isso, e não descobrir por um erro
  # de formulário depois de escrever a motivação.
  def pending_credentials
    @profile.credentials.where.not(verification_status: :verified)
  end

  def professional_registration? = @profile.valid_professional_registration?
end
