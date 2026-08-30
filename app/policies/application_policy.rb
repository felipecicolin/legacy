# frozen_string_literal: true

# Base de toda policy. A pergunta que uma policy responde nunca é "que tipo de
# usuário é este", e sim "esta pessoa pode fazer isto NESTE objeto" — por isso
# ela recebe o registro, e por isso papel não é coluna em `User`. Ver
# docs/authorization.md.
#
# Recebe um `Authorization::Context`, não um `User`: o contexto já traz perfil,
# papel de plataforma e vínculos aceitos, resolvidos uma vez por request.
class ApplicationPolicy
  def initialize(context, record)
    @context = context
    @record = record
  end

  # Fechado por padrão, e o default é `false` em vez de "staff pode tudo": um
  # default permissivo faz o esquecimento de escrever a regra virar acesso
  # concedido, que é o erro que não aparece em teste nenhum.
  def index? = false

  def show? = false

  def create? = false

  def new? = create?

  def update? = false

  def edit? = update?

  def destroy? = false

  private

  attr_reader :context, :record
end
