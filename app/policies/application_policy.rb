# frozen_string_literal: true

# Base de toda policy. A pergunta que uma policy responde nunca é "que tipo de
# usuário é este", e sim "esta pessoa pode fazer isto NESTE objeto" — por isso
# ela recebe o registro, e por isso papel não é coluna em `User`. Ver
# docs/authorization.md.
#
# Recebe um `Authorization::Context`, não um `User`: o contexto já traz perfil,
# papel de plataforma e vínculos aceitos, resolvidos uma vez por request.
class ApplicationPolicy
  class Scope
    attr_reader :context, :scope

    def initialize(context, scope)
      @context = context
      @scope = scope
    end

    def resolve = scope.all
  end

  attr_reader :context, :record

  def initialize(context, record)
    @context = context
    @record = record
  end

  def access? = context.signed_in?

  def public_access? = true

  def staff_access? = context.staff?

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

  protected

  def staff_at_least?(level)
    return false unless context.staff_level

    StaffRole.staff_levels.fetch(context.staff_level.to_s) >= StaffRole.staff_levels.fetch(level.to_s)
  end

  def visible_record?
    return false unless record
    return record.approved? if record.is_a?(Organization)

    record.class.visible_to(context.visibility).exists?(record.id)
  end
end
