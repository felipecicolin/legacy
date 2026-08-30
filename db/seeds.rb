# frozen_string_literal: true

# Carga do vocabulário curado. O seed lê `db/vocabulary/`, nunca redigita a
# lista aqui: a lista que ninguém abre é a que fica errada.
#
# Idempotente — casa pelo `iso_code` e atualiza a linha existente, para que uma
# mudança de curadoria (marcar um país como `high_risk`) alcance também os
# países já gravados. Ver docs/vocabulary.md.
Country.load_vocabulary!

# Regiões não entram aqui: carregar a subdivisão administrativa do mundo
# inteiro é dado para manter em dia sem ninguém para reclamar quando
# envelhecer. Região nasce junto com a obra que fica nela.

if Rails.env.development? || Rails.env.test?
  Rails.root.glob("db/seeds/development/*.rb").sort.each { |file| load file }
end
