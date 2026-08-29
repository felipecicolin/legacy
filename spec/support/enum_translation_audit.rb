# frozen_string_literal: true

# Rótulo de enum na UI: a convenção é `<enum no plural>.<valor>` no topo do
# locale (`statuses.draft`), como qualquer vocabulário resolvido em runtime.
# Ver docs/i18n.md.
#
# A auditoria mora fora do exemplo de propósito: hoje nenhum modelo tem enum,
# então um guarda escrito direto no spec varreria um conjunto vazio e passaria
# para sempre — inclusive depois do primeiro enum chegar sem rótulo. Separado,
# ele pode ser exercitado contra um modelo falso e provar que reprova.
module EnumTranslationAudit
  module_function

  def missing_keys(models)
    models.flat_map { |model| expected_keys(model) }.reject { |key| I18n.exists?(key) }
  end

  def expected_keys(model)
    model.defined_enums.flat_map { |name, values| values.keys.map { |value| "#{name.pluralize}.#{value}" } }
  end
end
