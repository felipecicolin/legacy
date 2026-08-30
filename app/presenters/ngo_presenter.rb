# frozen_string_literal: true

# O que a tela da base pode dizer, dado quem está olhando.
#
# A política de sensibilidade é do `Sensitive` e a de identidade é do
# `ProfilePresenter`; o que mora aqui é a composição das duas para uma tela —
# quais seções existem, e com que granularidade. Ver docs/field.md.
class NgoPresenter
  def initialize(ngo, context)
    @ngo = ngo
    @context = context
  end

  # País sempre, região só para quem alcança o nível do registro. Quem responde
  # é o concern; aqui só se escolhe o contexto.
  def location = @ngo.location_label(@context)

  # Coordenada não é dado de tela: ela some do HTML inteiro quando o leitor não
  # alcança o registro. Um `confidential` sequer a persiste — esta guarda cobre
  # o `restricted` visto por quem só alcança `public`.
  def precise_location
    return unless @context.can_see_precise_location?(@ngo)
    return if @ngo.latitude.blank? || @ngo.longitude.blank?

    [@ngo.latitude, @ngo.longitude]
  end

  # Todas as obras, inclusive concluídas, em ordem cronológica: é o histórico
  # que responde "esta base recebeu três obras em cinco anos". Ordenar por
  # estado esconderia justamente isso.
  def project_history
    @ngo.projects.order(:created_at, :id)
  end

  # Só as necessidades DA BASE — as que não pertencem a obra nenhuma. É o
  # cenário que motivou separar base de obra, e misturá-las com as das obras
  # apagaria a distinção que esta tela existe para provar.
  def standing_needs
    @ngo.needs.where(project_id: nil).need_status_open.by_priority
  end

  # Agrupada por obra, porque foto de obra sem obra é foto de lugar nenhum.
  # `includes` do anexo e do blob: os dois são N+1 por padrão.
  def gallery
    ProjectPhoto.where(project: project_history).includes(image_attachment: :blob).ordered.group_by(&:project_id)
  end

  # A legenda do design system é "data e responsável", e quem decide se o
  # responsável aparece é `ProjectPhoto#credit_for` — a política de identidade
  # já mora lá, e reescrevê-la aqui criaria uma segunda resposta para a mesma
  # pergunta.
  def photo_caption(photo)
    [I18n.l(photo.taken_on), photo.credit_for(@context)].compact.join(" · ")
  end
end
