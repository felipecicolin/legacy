# frozen_string_literal: true

require "vips"

# Uma foto com coordenada GPS no EXIF, gerada na hora.
#
# Gerada, e não commitada como fixture binária, por duas razões: um `.jpg` no
# repositório não conta a ninguém que ele existe para carregar um GPS, e a
# própria libvips que escreve o tag aqui é a que o `ExifScrubber` usa para
# apagá-lo — se a versão instalada mudar de comportamento, o teste muda junto,
# em vez de continuar medindo um arquivo de 2026.
module GeotaggedPhoto
  # Coordenada inventada, mas com a forma real: o IFD 3 é o de GPS, e é ele que
  # localiza a base com precisão de metros.
  TAGS = {
    "exif-ifd3-GPSLatitude" => "22/1 54/1 0/1 (22.9)",
    "exif-ifd3-GPSLongitude" => "43/1 12/1 0/1 (43.2)",
    "exif-ifd0-Make" => "CameraDaBase",
  }.freeze

  # O fabricante é procurado em texto puro nos bytes do arquivo: é o jeito de
  # perguntar "o bloco de metadados saiu?" sem depender de a libvips reabrir e
  # reinterpretar o que sobrou.
  MARKER = "CameraDaBase"

  def self.bytes
    image = Vips::Image.black(64, 48).add(120).cast(:uchar)
    image.bandjoin([image, image]).copy(interpretation: :srgb).mutate do |mutable|
      TAGS.each { |name, value| mutable.set_type!(GObject::GSTR_TYPE, name, value) }
    end.write_to_buffer(".jpg")
  end

  def self.exif_fields(bytes)
    Vips::Image.new_from_buffer(bytes, "").get_fields.grep(/\Aexif-/)
  end

  def self.upload(filename: "obra.jpg")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), "image/jpeg", original_filename: filename)
  end

  # Uma imagem de VERDADE num formato que a plataforma não serve.
  #
  # Precisa ser real, e não um JPEG rotulado de TIFF: o Active Storage
  # reidentifica o content-type pelos BYTES na ingestão, então mentir no
  # formulário não produz o caso — o blob volta como `image/jpeg` e passa pela
  # whitelist. É esse mesmo comportamento que faz o content-type declarado não
  # ser uma superfície de ataque aqui.
  #
  # TIFF, e não GIF: o `tiffsave` da libvips está sempre presente, e o `gifsave`
  # depende de a cgif ter sido compilada junto.
  def self.unserved_format_upload
    bytes = Vips::Image.black(32, 24).add(100).cast(:uchar).write_to_buffer(".tif")

    Rack::Test::UploadedFile.new(StringIO.new(bytes), "image/tiff", original_filename: "obra.tif")
  end
end
