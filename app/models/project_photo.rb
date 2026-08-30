# frozen_string_literal: true

# A foto da obra. É o principal conteúdo visual da plataforma e o que dá
# credibilidade ao relatório — e é também o vetor de vazamento mais fácil de
# esquecer: uma foto carrega GPS, placa de rua, rosto e fachada, quatro formas
# de identificar uma base em país perseguido. Ver docs/photo-policy.md.
class ProjectPhoto < ApplicationRecord
  include ScrubbedPhoto

  # Whitelist, e não blacklist: formato que não está aqui não entra, em vez de
  # formato conhecido-ruim ficar de fora enquanto o próximo passa.
  CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  # 12 MB. Foto de celular moderna cabe; PDF de planta e vídeo não — e é
  # justamente o upload acidental desses que enche o storage sem ninguém ver.
  MAX_MEGABYTES = 12
  MAX_BYTE_SIZE = MAX_MEGABYTES.megabytes

  # O `ExifScrubber` FECHA a porta levantando `Unsupported` quando a libvips não
  # abre os bytes, e isso é o desenho certo: reescrever o arquivo "como está"
  # devolveria o EXIF intacto com cara de limpo. Mas exceção no writer vira 500
  # no formulário, e o que a pessoa fez foi escolher o arquivo errado.
  #
  # `prepend`, e não `def image=` no corpo da classe: o writer que
  # `attaches_scrubbed_photo` instala é definido NA CLASSE com `define_method`,
  # então um `def` aqui o SUBSTITUIRIA — e a foto subiria com o EXIF dentro,
  # sem erro nenhum. Prepend roda antes e delega por `super`, mantendo a limpeza
  # no caminho e os bytes fora do storage.
  module RefusesUnreadableImage
    def image=(attachable)
      self.unreadable_image = false
      super
    rescue ExifScrubber::Unsupported
      self.unreadable_image = true
    end
  end

  prepend RefusesUnreadableImage

  # Atributo virtual, e não variável de instância: o Active Record o inicializa
  # em todo registro novo, e a validação abaixo não precisa supor estado.
  attribute :unreadable_image, :boolean, default: false

  # O EXIF é destruído na ingestão SEMPRE, e não só em obra confidencial.
  # Regra única é regra que não se esquece — e a obra pode ser promovida a
  # confidencial depois da foto já estar guardada.
  attaches_scrubbed_photo :image

  belongs_to :project
  belongs_to :progress_report, optional: true
  belongs_to :taken_by, class_name: "Profile", optional: true, inverse_of: :project_photos

  enum :category, { before: 0, during: 1, after: 2, detail: 3, team: 4 }, validate: true, prefix: true

  scope :ordered, -> { order(:category, :position, :id) }

  validates :taken_on, presence: true, comparison: { less_than_or_equal_to: -> { Date.current } }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :attached_image_is_usable

  def category_label
    I18n.t(category, scope: :photo_categories)
  end

  # A legenda omite quem tirou a foto quando o contexto não alcança o registro:
  # nomear a pessoa ao lado de uma obra confidencial é exatamente o que a
  # política de identidade evita. Quem decide é o recurso, não o perfil.
  def credit_for(context)
    return if taken_by.blank? || !context.can_identify?(project)

    taken_by.to_s
  end

  private

  # Uma checagem só, com saída na primeira recusa. Três validações separadas
  # perguntariam `image.attached?` três vezes e diriam três coisas sobre um
  # anexo que talvez nem exista.
  def attached_image_is_usable
    problem = image_problem
    errors.add(:image, problem, limit: MAX_MEGABYTES) if problem
  end

  def image_problem
    return :unsupported_picture if unreadable_image?
    return :blank unless image.attached?
    return :unsupported_picture unless CONTENT_TYPES.include?(image.blob.content_type)

    :too_large unless within_size_limit?
  end

  def within_size_limit? = image.blob.byte_size <= MAX_BYTE_SIZE
end
