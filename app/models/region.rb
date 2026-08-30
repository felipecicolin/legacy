# frozen_string_literal: true

# Subdivisão administrativa. É a granularidade que sobra para um registro
# confidential — país sempre, região quando ela não localiza ninguém — e a
# chave do agregado anonimizado. Ver docs/visibility.md.
#
# Não se carrega a subdivisão do mundo inteiro: região entra quando existe obra
# nela. Uma tabela com 5.000 linhas que ninguém referencia é dado para manter
# em dia sem ninguém para reclamar quando envelhecer.
class Region < ApplicationRecord
  belongs_to :country, inverse_of: :regions

  # Mesma direção do país: a região existe porque há obra nela, então
  # apagá-la com base apontando é erro, não limpeza.
  has_many :mission_bases, dependent: :restrict_with_error, inverse_of: :region

  # O nome da região é dado, e não chave de locale como o do país: ele varia
  # com o idioma local da equipe em campo, e não existe lista fechada dele.
  validates :name, presence: true, uniqueness: { scope: :country_id }
end
