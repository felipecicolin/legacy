# frozen_string_literal: true

# A pessoa. Uma só, com muitos papéis — não existem `Volunteer`, `Investor` e
# `Missionary` separados, porque o domínio descreve gente que é as três coisas
# ao mesmo tempo. "Visão do investidor" é projeção autorizada sobre estes
# dados, não outro tipo de registro.
#
# O `User` guarda credencial e sessão; tudo que é pessoa mora aqui.
class Profile < ApplicationRecord
  # Nome legal não sai por serialização. Ver `#serializable_hash`.
  HIDDEN_ATTRIBUTES = %w[legal_name].freeze

  belongs_to :user
  has_one_attached :avatar

  validates :legal_name, :display_name, presence: true

  # Quem de fato garante um perfil por pessoa é o índice único — validação
  # perde a corrida entre dois requests concorrentes. A validação existe para
  # a segunda tentativa virar erro de formulário em vez de exceção de driver,
  # e é ela que o `database_consistency` cobra ao ver o índice único.
  validates :user_id, uniqueness: true

  before_validation :default_display_name, on: :create

  # Interpolar um perfil numa view tem de sair o nome público. Se `to_s`
  # devolvesse `legal_name`, bastaria um `"#{profile}"` esquecido numa
  # listagem para vazar a identidade legal de quem trabalha em país sensível.
  def to_s = display_name

  # A mesma garantia para qualquer coisa que serialize: `as_json`, `to_json` e
  # todo serializer que passe por aqui.
  #
  # A remoção é incondicional de propósito. Devolver o `except:` só como
  # padrão não bastaria: no `serializable_hash` do Active Model o `only:` tem
  # precedência sobre o `except:`, então um `as_json(only: [:legal_name])`
  # atravessaria a defesa.
  def serializable_hash(options = nil)
    super.except(*HIDDEN_ATTRIBUTES)
  end

  private

  # `display_name` nasce copiando `legal_name`, mas fica ARMAZENADO. Derivar
  # em tempo de leitura faria a correção de um nome legal reescrever
  # retroativamente todo o histórico já exibido.
  def default_display_name = self.display_name ||= legal_name
end
