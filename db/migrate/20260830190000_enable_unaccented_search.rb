# frozen_string_literal: true

class EnableUnaccentedSearch < ActiveRecord::Migration[8.1]
  # "sao paulo" tem de achar "São Paulo". Sem `unaccent` a busca vira
  # comparação de bytes, e quem digita sem acento — a maioria de quem digita
  # rápido — não acha nada e conclui que o dado não existe.
  #
  # Só a extensão, e o `unaccent()` é chamado na CONSULTA. Não há índice
  # funcional aqui, e a razão é a mesma que fez o código da obra virar coluna
  # gerada: o `unaccent` é `STABLE`, o Postgres recusa função não-imutável em
  # índice, e o embrulho imutável de sempre (`create function f_unaccent ...`)
  # **não é dumpado pelo `schema.rb`**. O banco de teste nasce do schema, então
  # o índice referenciaria uma função inexistente e o `db:schema:load` morre —
  # medido, não suposto.
  #
  # O custo é varredura sequencial na busca. Para o volume da demonstração isso
  # não se nota, e escolher o índice certo com `EXPLAIN` sobre o seed é
  # exatamente o trabalho de #49. Ver docs/search.md.
  def change
    enable_extension "unaccent"
  end
end
