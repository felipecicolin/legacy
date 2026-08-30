# frozen_string_literal: true

# Modelo de teste para o Action Text.
#
# Existe porque a #32 instala a infraestrutura antes de existir domínio: nenhum
# dos modelos que vão usar texto rico (`Ngo`, `Ngo`, `Project`,
# `SiteSurvey`, `ProgressReport`) foi escrito ainda, e criar um modelo de
# aplicação só para o teste colocaria em `app/` código que ninguém chama.
#
# A tabela nasce e morre com a suíte, fora do `db/schema.rb` — o schema
# commitado descreve o banco de produção, e uma tabela de teste dentro dele
# mentiria para o `database_consistency` e para quem lê o arquivo.
class RichTextProbe < ApplicationRecord
  has_rich_text :body
end

RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Base.connection.create_table(:rich_text_probes, force: true, &:timestamps)
    end
  end
end
