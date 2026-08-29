# frozen_string_literal: true

# Sessão é linha no banco, não cookie assinado com o id do usuário. O cookie
# guarda só o id desta linha, então encerrar sessão é apagar a linha — e um
# cookie antigo reapresentado depois disso não reautentica ninguém.
class Session < ApplicationRecord
  belongs_to :user
end
