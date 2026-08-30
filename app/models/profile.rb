# frozen_string_literal: true

# A pessoa. Uma só, com muitos papéis — não existem `Volunteer`, `Investor` e
# `Missionary` separados, porque o domínio descreve gente que é as três coisas
# ao mesmo tempo. "Visão do investidor" é projeção autorizada sobre estes
# dados, não outro tipo de registro.
#
# O `User` guarda credencial e sessão; tudo que é pessoa mora aqui.
class Profile < ApplicationRecord
  include ScrubbedPhoto

  # Nome legal não sai por serialização. Ver `#serializable_hash`.
  HIDDEN_ATTRIBUTES = %w[legal_name].freeze

  belongs_to :user

  # A foto de perfil entra pelo mesmo pipeline das demais: "sempre e para todas
  # as fotos" só é verdade se valer também para o único anexo que já existe.
  # Um retrato tirado no celular numa base de país perseguido carrega a
  # coordenada da base no EXIF, igual à foto da obra.
  attaches_scrubbed_photo :avatar
  has_many :credentials, dependent: :destroy

  # `legal_name` fora do `inspect`, que é o que vai para a linha de log de
  # exceção e para o rastreador de erros. Espelha o que `Sensitive` faz com a
  # coordenada, e pelo mesmo motivo: o `serializable_hash` abaixo cobre a
  # resposta, e esta é a outra porta.
  self.filter_attributes |= HIDDEN_ATTRIBUTES

  # Papel é contexto, e o contexto mora do outro lado: nenhuma coluna aqui diz
  # "esta pessoa é dona de alguma coisa". Ver docs/organizations.md.
  #
  # `dependent: :destroy` apaga os vínculos junto com a pessoa — menos quando um
  # deles é a última posse de uma organização que continua existindo. Aí o
  # `Membership` recusa, e apagar a pessoa reprova em vez de deixar uma
  # organização sem dono.
  #
  # A recusa é silenciosa deste lado: `destroy` volta `false` e desfaz tudo, mas
  # os erros ficam no `Membership` que recusou e `profile.errors` volta VAZIO.
  # Quem construir a tela de exclusão de conta precisa perguntar antes — "estas
  # organizações ficariam sem dono" — em vez de tentar apresentar o erro depois.
  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :project_participations, dependent: :destroy
  has_many :projects, through: :project_participations
  has_many :surveyed_site_surveys, class_name: "SiteSurvey", foreign_key: :surveyed_by_id,
                                   dependent: :restrict_with_error, inverse_of: :surveyed_by
  has_many :reported_progress_reports, class_name: "ProgressReport", foreign_key: :reported_by_id,
                                       dependent: :restrict_with_error, inverse_of: :reported_by
  has_many :approved_progress_reports, class_name: "ProgressReport", foreign_key: :approved_by_id,
                                       dependent: :nullify, inverse_of: :approved_by
  has_many :taken_project_photos, class_name: "ProjectPhoto", foreign_key: :taken_by_id,
                                  dependent: :nullify, inverse_of: :taken_by

  validates :legal_name, :display_name, presence: true

  # As duas colunas são NOT NULL com default, e é justamente o default que faz
  # o `database_consistency` não cobrar presença aqui. Sem a validação, um
  # `nil` vindo de um PATCH chega ao banco e volta como
  # `ActiveRecord::NotNullViolation` — exceção de driver no meio do request —,
  # e um `""` seria gravado como fuso vazio, que quebra na primeira leitura.
  validates :preferred_locale, :timezone, presence: true

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

  # É o ponto de consulta que a futura Candidacy usa para decidir se uma
  # necessidade que exige registro profissional pode receber esta pessoa.
  def valid_professional_registration?
    credentials.any?(&:valid_for_professional_registration?)
  end

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
  #
  # `presence` e não `||=`: campo de texto vazio chega do formulário como `""`,
  # que é truthy. Com `||=` o default não correria e o campo apresentado como
  # opcional reprovaria a criação.
  def default_display_name = self.display_name = display_name.presence || legal_name
end
