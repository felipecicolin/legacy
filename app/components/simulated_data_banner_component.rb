# frozen_string_literal: true

# A marca visível de que o dinheiro na tela é de mentira.
#
# Fica no layout, e não na tela de arrecadação, de propósito: assim toda tela
# nasce marcada e nenhuma precisa lembrar. Uma prestação de contas que parece
# real e não é vira problema de confiança no primeiro print compartilhado fora
# de contexto — e o print sai da tela que alguém esqueceu de marcar.
#
# O `render?` pergunta ao provedor, não ao ambiente: `Rails.env.production?`
# responderia errado numa demo publicada, que é justamente onde o aviso mais
# importa. Quando o provedor deixar de ser simulado, o banner some sozinho.
class SimulatedDataBannerComponent < ApplicationComponent
  def initialize(classes: nil)
    super()
    @classes = classes
  end

  def render?
    Payments::Gateway.simulated?
  end

  # `bg-warning-soft` com `text-warning` é o par suave do vocabulário de
  # estado: passa AA e diz "atenção", não "erro" — o dado simulado não é uma
  # falha, é uma condição da instalação.
  def computed_classes
    class_merge("flex items-center gap-2 rounded-lg border border-warning bg-warning-soft " \
                "px-4 py-3 text-sm text-warning", @classes)
  end
end
