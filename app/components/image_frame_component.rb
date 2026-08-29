# frozen_string_literal: true

class ImageFrameComponent < ApplicationComponent
  # Proporção pedida => utility do `@theme inline`. O mapa existe para que
  # ninguém escreva `aspect-[16/9]`: valor arbitrário é proibido, e
  # enquadramento é vocabulário do design system, não da view.
  RATIO_CLASSES = {
    "16/9" => "aspect-wide",
    "4/3" => "aspect-photo",
    "1/1" => "aspect-tile",
  }.freeze

  RATIOS = RATIO_CLASSES.keys.freeze

  # As três larguras do `srcset`. Cobrem o telefone, o cartão de grade e a
  # coluna larga do desktop; acima de 1440 a imagem cresce sem ganhar detalhe.
  WIDTHS = [480, 960, 1440].freeze

  # Coerente com o grid de galeria: coluna única no telefone, duas colunas a
  # partir de 768px, três a partir de 1280px. Quem usa outro grid passa o seu.
  DEFAULT_SIZES = "(min-width: 1280px) 33vw, (min-width: 768px) 50vw, 100vw"

  # A imagem é `absolute` para sair do fluxo: quem reserva a altura é o
  # `aspect-*` da moldura, e o que não ocupa espaço não empurra nada quando
  # chega. O apoio ocupa o mesmo retângulo, atrás dela.
  CLASSES = {
    frame: "relative w-full overflow-hidden rounded-lg bg-muted",
    image: "absolute inset-0 h-full w-full object-cover",
    fallback: "absolute inset-0 flex flex-col items-center justify-center gap-2 " \
              "p-4 text-center text-sm text-muted-foreground",
  }.freeze

  # A legenda (data e responsável) é slot, e não parâmetro, porque quem exibe
  # decide o que cabe ali: a política de nome público pode proibir mostrar o
  # responsável, e a moldura não tem como saber disso.
  renders_one :caption

  # Um Data em vez de quatro ivars soltas: o `TooManyInstanceVariables` do reek
  # para em quatro, e o blob normalizado já ocupa uma delas.
  Attrs = Data.define(:alt, :ratio, :sizes, :classes)
  private_constant :Attrs

  def initialize(attachment:, alt:, ratio: "16/9", sizes: DEFAULT_SIZES, classes: nil)
    super()
    validate_inclusion!(:ratio, ratio, RATIOS)
    @blob = extract_blob(attachment)
    @attrs = Attrs.new(alt: alt, ratio: ratio, sizes: sizes, classes: classes)
  end

  # Um anexo que não vira variante nunca vira `<img>`: dizer "processando" nele
  # seria mentira, porque nada está em curso. Cai no mesmo quadro do vazio.
  def ready?
    variable? && @blob.analyzed?
  end

  def processing?
    variable? && !@blob.analyzed?
  end

  # `hidden` chega ao controller como classe declarada, e não escrita no JS:
  # é utility do Tailwind, e o lugar de uma classe de CSS é o template.
  def frame_options
    { class: class_merge(CLASSES.fetch(:frame), RATIO_CLASSES.fetch(@attrs.ratio), @attrs.classes),
      data: { controller: stimulus_controller, "#{stimulus_controller}-hidden-class": "hidden" } }
  end

  def srcset
    WIDTHS.map { |width| "#{variant_url(width)} #{width}w" }.join(", ")
  end

  # O quadro de apoio fica ATRÁS da imagem e some sob ela quando ela carrega —
  # por isso, no estado pronto, ele é decoração e sai do fluxo do leitor de
  # tela: quem descreve a imagem ali é o `alt`. Nos outros estados o texto do
  # quadro é o conteúdo, e tem de ser anunciado.
  def fallback_options
    options = { class: CLASSES.fetch(:fallback),
                data: { "#{stimulus_controller}-target": "fallback" } }
    ready? ? options.merge(aria: { hidden: true }) : options
  end

  delegate :alt, to: :@attrs

  def image_options
    { src: variant_url(WIDTHS.fetch(1)), srcset: srcset, sizes: @attrs.sizes,
      loading: "lazy", decoding: "async", class: CLASSES.fetch(:image),
      data: { "#{stimulus_controller}-target": "image",
              action: "error->#{stimulus_controller}#failed" } }
  end

  private

  # Aceita o proxy do `has_one_attached`, um `ActiveStorage::Attachment`, um
  # blob solto ou `nil`. Quem chama não deveria precisar saber qual dos quatro
  # tem em mãos, e sem isso a moldura só serviria a um deles. `try` em vez de
  # `respond_to?` porque as quatro formas implementam subconjuntos diferentes
  # da mesma API: perguntar "você tem este método?" a cada uma espalharia o if.
  def extract_blob(attachment)
    return if attachment.try(:attached?) == false

    attachment.try(:blob) || attachment
  end

  # `variable?`, e não `representable?`: este último também é verdadeiro para o
  # que o Active Storage sabe *pré-visualizar* — PDF pelo poppler, vídeo pelo
  # ffmpeg —, e sobre esses `blob.variant` levanta `InvariableError`. O que a
  # `<img>` daqui pede é variante; prévia é outro produto, com outra dependência
  # de sistema (o Dockerfile instala só a libvips).
  def variable?
    @blob&.variable?
  end

  def variant_url(width)
    helpers.url_for(@blob.variant(resize_to_limit: [width, nil]))
  end
end
