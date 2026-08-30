# frozen_string_literal: true

# Qual dos dois nomes de uma pessoa aparece, e em que contexto.
#
# O `Profile` guarda `legal_name` e `display_name` (#18) e não decide nada
# sobre eles; a decisão é de política, e mora aqui. Ao lado de um recurso que
# o leitor não alcança, a pessoa aparece pela forma reduzida — o papel sem
# nome. Ver docs/photo-policy.md.
class ProfilePresenter
  # `role_label` chega TRADUZIDO de quem chama, e isso é deliberado: o
  # vocabulário de papel é das #20, #21 e #31, e inventá-lo aqui criaria um
  # segundo conjunto de rótulos para as mesmas coisas. O que mora aqui é a
  # política — qual dos dois aparece —, não o vocabulário.
  #
  # `subject` é o recurso ao lado do qual a pessoa está sendo mostrada, e é
  # obrigatório: uma pessoa renderizada "solta", sem cena, não tem como ser
  # avaliada, e um default nulo viraria a resposta permissiva por omissão.
  def initialize(profile, role_label:, subject:)
    @profile = profile
    @role_label = role_label
    @subject = subject
  end

  # `display_name` é NOT NULL e validado presente, então o `||` só cai no
  # papel quando a política recusou — nunca por nome vazio.
  def name_for(context)
    identified_name(context) || @role_label
  end

  # A legenda do design system é "data e responsável". Quando o contexto não
  # pode identificar, o responsável SAI inteiro — não vira rótulo de papel:
  # numa legenda de foto o papel não acrescenta informação e ainda estreita o
  # conjunto de quem pode ter tirado aquela foto, que é o oposto do que a
  # forma reduzida existe para fazer.
  def caption_for(context, taken_on:)
    [I18n.l(taken_on), identified_name(context)].compact.join(" · ")
  end

  private

  def identified_name(context)
    @profile.display_name if context.can_identify?(@subject)
  end
end
