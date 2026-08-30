# frozen_string_literal: true

# Destrói os metadados de uma foto ANTES de ela virar blob.
#
# EXIF carrega coordenada GPS, e uma foto de base missionária publicada com o
# EXIF intacto localiza a base com precisão de metros. Por isso isto não é um
# filtro de exibição nem um job que passa depois: é o mesmo princípio da
# coordenada em `Sensitive` — dado que não existe não vaza por view, por log,
# por export nem por backup. Os bytes com GPS nunca chegam ao serviço de
# storage. Ver docs/photo-policy.md.
class ExifScrubber
  # O anexo cujos bytes JÁ estão armazenados: um blob pronto, ou o signed id
  # que o direct upload devolve. Não dá para prometer destruição na ingestão
  # sobre eles — a ingestão já aconteceu, num caminho que ninguém limpou —,
  # então a porta se fecha em vez de fingir que limpou.
  class AlreadyStored < StandardError; end

  # O que a libvips não consegue abrir como imagem não é foto, e reescrever o
  # arquivo "como está" seria devolver o EXIF intacto com cara de limpo.
  class Unsupported < StandardError; end

  Source = Data.define(:io, :filename, :content_type)
  private_constant :Source

  # Formato de saída sem extensão de origem para deduzir: a libvips escolhe o
  # codificador pela extensão do destino, e um nome sem ponto a deixaria sem
  # escolha nenhuma.
  FALLBACK_EXTENSION = ".jpg"
  private_constant :FALLBACK_EXTENSION

  # `nil` e `""` são o caminho de REMOÇÃO do anexo, e passam intactos: não há
  # bytes para limpar, e traduzi-los quebraria o `photo = nil`.
  def self.call(attachable)
    return attachable if attachable.blank?

    new(attachable).scrubbed
  end

  def initialize(attachable)
    raise AlreadyStored, attachable.class.name if attachable.is_a?(ActiveStorage::Blob) ||
                                                  attachable.is_a?(String)

    @attachable = attachable
    @source = normalize
  end

  # A forma de hash é a única que o Active Storage aceita sem consultar disco,
  # e é ela que garante que o que sobe é o arquivo limpo, não o original.
  def scrubbed
    { io: stripped, filename: @source.filename, content_type: @source.content_type }.compact
  end

  private

  # `try` em vez de `respond_to?` pelo mesmo motivo do `ImageFrameComponent`:
  # as formas aceitas implementam subconjuntos diferentes da mesma API, e
  # perguntar "você tem este método?" a cada uma espalha o if.
  def normalize
    return hash_source if @attachable.is_a?(Hash)
    return uploaded if @attachable.try(:original_filename)
    return path_source if @attachable.try(:to_path)

    raise Unsupported, @attachable.class.name
  end

  # As três chaves saem lidas uma a uma, e não por `slice`, porque o `Data`
  # exige todos os membros: um hash sem `content_type` — que o Active Storage
  # aceita, e identifica o tipo sozinho — levantaria `ArgumentError` antes de
  # chegar à limpeza.
  def hash_source
    fields = @attachable.symbolize_keys

    Source.new(io: fields[:io], filename: fields[:filename], content_type: fields[:content_type])
  end

  def uploaded
    Source.new(io: @attachable, filename: @attachable.original_filename,
               content_type: @attachable.content_type)
  end

  def path_source
    Source.new(io: @attachable, filename: File.basename(@attachable.to_path), content_type: nil)
  end

  # `saver(strip: true)` é o que apaga o bloco inteiro de metadados — EXIF,
  # IPTC e XMP —, e não só o IFD de GPS: fabricante, número de série da câmera
  # e miniatura embutida também dizem de quem e de onde é a foto.
  def stripped
    ImageProcessing::Vips.source(readable).saver(strip: true).call
  rescue Vips::Error => error
    raise Unsupported, error.message
  end

  # Cópia para arquivo temporário em vez de repassar o que veio: o
  # `ImageProcessing` precisa de algo com caminho, e o `IO.copy_stream` cobre
  # de uma vez o `UploadedFile`, o `StringIO`, o `File` e o `Pathname`.
  def readable
    file = Tempfile.new(["photo", extension], binmode: true)
    IO.copy_stream(@source.io, file)
    file.tap(&:rewind)
  end

  def extension
    File.extname(@source.filename.to_s).presence || FALLBACK_EXTENSION
  end
end
