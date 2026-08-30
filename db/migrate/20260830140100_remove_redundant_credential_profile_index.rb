# frozen_string_literal: true

# O `t.references :profile` da migration de `credentials` cria
# `index_credentials_on_profile_id`, e o `add_index [:profile_id, :kind]` logo
# abaixo cria um índice cujo PREFIXO É a mesma coluna — o Postgres atende por
# ele toda consulta que o primeiro atenderia, inclusive a checagem da FK.
#
# Dois índices sobre o mesmo prefixo custam escrita e espaço em toda inserção
# sem devolver leitura nenhuma, e é isso que o `RedundantIndexChecker` do
# `database_consistency` aponta. A migration original não é editada porque ela
# já rodou na demo implantada: desfazer é migration nova.
class RemoveRedundantCredentialProfileIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :credentials, :profile_id
  end
end
