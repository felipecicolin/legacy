# frozen_string_literal: true

class CredentialDocumentsController < ApplicationController
  def show
    document = authorized_credential.document
    return head(:not_found) unless document.attached?

    send_document(document)
  end

  private

  # `find`, e não um escopo pelo perfil da sessão: quem decide é a policy, e a
  # busca sem filtro é o que permite a quem verifica registro profissional
  # alcançar o documento de outra pessoa. Inexistente e não autorizado saem
  # pela mesma porta — as duas exceções caem no mesmo `rescue_from`.
  def authorized_credential
    authorize Credential.find(params.expect(:id))
  end

  def send_document(document)
    send_data document.download,
              filename: document.filename.to_s,
              content_type: document.content_type,
              disposition: "attachment"
  end
end
