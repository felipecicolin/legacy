# frozen_string_literal: true

# A moldura das telas de autenticação: painel de imagem à esquerda, formulário
# à direita.
#
# É componente, e não marcação solta no layout, porque o painel é vocabulário
# reutilizável — acesso, recuperação e definição de senha são a mesma tela com
# outro conteúdo — e porque assim ele tem preview: dá para olhar o split sem
# deslogar.
class AuthLayoutComponent < ApplicationComponent
  # A imagem é slot para que trocar o apoio por uma foto de verdade não mexa
  # neste arquivo. Enquanto ela não existe, o padrão é um painel de apoio que
  # ocupa o mesmo retângulo — o enquadramento não muda quando a foto chegar.
  renders_one :illustration

  def html_attributes
    html_options.merge(class: computed_classes)
  end

  # `flex-row-reverse`: no DOM o formulário vem ANTES do painel, e só a pintura
  # o joga para a direita. Assim teclado e leitor de tela chegam ao que a
  # pessoa veio fazer sem atravessar a ilustração, e a tela não precisa de link
  # de pular conteúdo — não há nada a pular.
  def computed_classes
    class_merge("flex min-h-screen w-full flex-row-reverse bg-background", html_options[:class])
  end
end
