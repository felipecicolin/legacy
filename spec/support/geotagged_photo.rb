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

  # 64 de largura por 48 de altura, para que uma rotação de 90 graus seja
  # visível na dimensão — é assim que o spec de orientação pergunta se os
  # pixels giraram.
  def self.canvas
    image = Vips::Image.black(64, 48).add(120).cast(:uchar)
    image.bandjoin([image, image]).copy(interpretation: :srgb)
  end

  def self.bytes
    canvas.mutate do |mutable|
      TAGS.each { |name, value| mutable.set_type!(GObject::GSTR_TYPE, name, value) }
    end.write_to_buffer(".jpg")
  end

  # `Orientation = 6` é "gire 90 graus ao exibir", que é o que o celular grava
  # ao fotografar em pé. A tag mora no bloco de EXIF, então ela some com o
  # resto — ver docs/photo-policy.md.
  def self.sideways_bytes
    canvas.mutate { |mutable| mutable.set_type!(GObject::GINT_TYPE, "orientation", 6) }
          .write_to_buffer(".jpg")
  end

  def self.exif_fields(bytes)
    Vips::Image.new_from_buffer(bytes, "").get_fields.grep(/\Aexif-/)
  end

  def self.upload(filename: "obra.jpg", data: bytes)
    Rack::Test::UploadedFile.new(StringIO.new(data), "image/jpeg", original_filename: filename)
  end
end
