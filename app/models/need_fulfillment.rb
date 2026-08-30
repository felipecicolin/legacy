# frozen_string_literal: true

# O abatimento de uma necessidade, venha ele de onde vier.
#
# A origem é polimórfica de propósito, e é a única vez que este repositório
# escolhe polimorfismo: necessidade de material é abatida por doação em
# espécie, a de recurso por contribuição financeira, a de mão de obra por
# alocação. Três origens, UM mecanismo — senão cada espécie de necessidade
# ganha a sua própria contabilidade e elas divergem.
#
# A diferença para o polimorfismo que `Need` recusou: lá havia um dono real com
# um qualificador opcional; aqui são três tipos genuinamente distintos, e
# nenhum deles é "o" dono. Ver docs/mobilization.md.
class NeedFulfillment < ApplicationRecord
  belongs_to :need
  belongs_to :source, polymorphic: true

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :fulfilled_at, presence: true
  validates :source_id, uniqueness: { scope: %i[need_id source_type] }
  validate :fits_in_what_is_left

  private

  # Lida DEPOIS do `lock!`: quem cria um abatimento passa por `Need#fulfill!`,
  # que trava a linha antes. Fora da trava esta validação continua correta e
  # continua sendo insuficiente — é o `CHECK` do banco que fecha a corrida.
  def fits_in_what_is_left
    return if need.blank? || quantity.blank?
    return if quantity <= need.remaining_quantity + already_counted

    errors.add(:quantity, :exceeds_what_is_left)
  end

  # Numa atualização, o que este mesmo registro já abatia não conta contra ele.
  def already_counted = persisted? ? (quantity_was || 0) : 0
end
