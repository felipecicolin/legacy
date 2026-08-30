# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += %i[
  passw email secret token _key crypt salt certificate otp ssn cvv cvc
]

# Localização precisa de obra em campo: `Parameters: {…}` é o outro caminho pelo
# qual a coordenada de uma base vai para o log, e ele não passa por modelo
# nenhum. O concern `Sensitive` fixa os mesmos nomes por modelo, para a garantia
# viajar com ele — aqui é o formulário que entra. Ver docs/visibility.md.
#
# A lista vai literal, e não como `Sensitive::PRECISE_LOCATION_ATTRIBUTES`:
# initializer roda antes do autoload, e referenciar a constante aqui derruba o
# boot com `uninitialized constant`. Mexeu numa lista, mexa na outra.
Rails.application.config.filter_parameters += %i[address latitude longitude]

# Nome do documento de quem trabalha em campo. `Profile#serializable_hash` já o
# tira de toda resposta e `Profile.filter_attributes` o tira do `inspect`; esta
# é a terceira porta, a do formulário — o `Parameters: {…}` do log de
# requisição não passa por modelo nenhum. Ver docs/identity.md.
#
# `display_name` NÃO entra: é o nome que a UI mostra, e filtrá-lo do log
# esconderia justamente o campo que ajuda a depurar a tela.
Rails.application.config.filter_parameters += %i[legal_name]
