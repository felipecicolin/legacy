# frozen_string_literal: true

# Falhar no boot deixa uma dependência ausente óbvia no Coolify. Sem esta
# verificação, o problema só aparece quando a primeira variante de imagem é
# solicitada.
require "vips"

libvips_version = Vips.version_string
raise LoadError, "libvips failed to load" if libvips_version.blank?

Rails.logger.info("libvips #{libvips_version} loaded")
