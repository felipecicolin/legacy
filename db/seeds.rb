# frozen_string_literal: true

# Carga do vocabulário curado. O seed lê `db/vocabulary/`, nunca redigita a
# lista aqui: a lista que ninguém abre é a que fica errada.
#
# Idempotente — casa pelo `iso_code` e atualiza a linha existente, para que uma
# mudança de curadoria (marcar um país como `high_risk`) alcance também os
# países já gravados. Ver docs/vocabulary.md.
Country.load_vocabulary!
Skill.load_vocabulary!

# Regiões não entram aqui: carregar a subdivisão administrativa do mundo
# inteiro é dado para manter em dia sem ninguém para reclamar quando
# envelhecer. Região nasce junto com a obra que fica nela.

# Camada de desenvolvimento: dado suficiente para preview de componente abrir
# com conteúdo e para consulta de agregação ter linha. Ela CRESCE junto com os
# modelos — cada issue de modelo acrescenta o seu arquivo aqui, em vez de a
# demonstração inteira (#48) esperar o fim.
#
# `production` fica de fora pelo nome do ambiente, e não por `development?`
# sozinho: teste também carrega, e é lá que o seed prova que roda.
unless Rails.env.production?
  Rails.root.glob("db/seeds/development/*.rb").sort.each { |file| load file }
  DevelopmentSeeds.load_all!
end
