# frozen_string_literal: true

module Authorization
  # Nível que cada papel da equipe alcança. `support` e `curator` NÃO ganham
  # `confidential`: quem atende chamado e quem cura vocabulário não precisa da
  # coordenada de uma base em país perseguido, e alcance que ninguém usa é
  # alcance que vaza por acidente. Ver docs/authorization.md.
  CLEARANCE_BY_STAFF_LEVEL = { support: :restricted, curator: :restricted, admin: :confidential }.freeze

  # Teto de quem entrou e não é da equipe. Era a constante
  # `AuthorizedBlobDelivery::SIGNED_IN_CLEARANCE`, que existia à espera desta
  # issue; o valor não mudou.
  SIGNED_IN_CLEARANCE = :restricted

  # Quem está perguntando, já resolvido: a pessoa, o perfil, o papel na
  # plataforma e os vínculos que valem. É o `pundit_user` deste projeto — as
  # policies recebem isto, e não o `User`.
  #
  # Um objeto, e não três parâmetros, por duas razões. A primeira é o limite de
  # 4 parâmetros do repositório, que uma policy com `(user, profile,
  # memberships, record)` já estoura. A segunda importa mais: os vínculos são
  # carregados UMA vez, na construção, em vez de a cada `authorize` do request.
  #
  # `memberships` guarda só os aceitos. Convite pendente não concede nada, e
  # filtrar aqui evita que cada policy lembre de perguntar `accepted?`.
  Context = Data.define(:user, :profile, :staff_level, :memberships) do
    def self.anonymous
      new(user: nil, profile: nil, staff_level: nil, memberships: [])
    end

    # Aceita `nil` de propósito: quem chama nem sempre sabe se há sessão, e um
    # contexto anônimo é resposta legítima — não um caso de erro.
    def self.for(user)
      return anonymous if user.blank?

      profile = user.profile
      new(user: user, profile: profile, staff_level: user.staff_role&.staff_level&.to_sym,
          memberships: profile ? profile.memberships.accepted.to_a : [])
    end

    def signed_in? = user.present?

    def staff? = staff_level.present?

    def platform_admin? = staff_level == :admin

    # Papel desta pessoa NESTA organização, ou `nil`. É a pergunta que as
    # policies fazem, e ela não vai ao banco: a resposta já está no contexto.
    def role_in(ngo)
      memberships.find { |membership| membership.ngo_id == ngo.id }&.role&.to_sym
    end

    # A ponte para a visibilidade. As duas perguntas são diferentes — "pode
    # fazer isto neste objeto" e "quanto deste mundo esta pessoa enxerga" — e é
    # por isso que são dois objetos; o que este lado sabe e o outro não é qual
    # papel a pessoa tem.
    def visibility
      Visibility::Context.new(clearance: clearance)
    end

    def clearance
      return :public unless signed_in?

      CLEARANCE_BY_STAFF_LEVEL.fetch(staff_level, SIGNED_IN_CLEARANCE)
    end
  end
end
