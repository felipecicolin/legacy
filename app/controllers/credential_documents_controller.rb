# frozen_string_literal: true

class CredentialDocumentsController < ApplicationController
  def show
    credential = accessible_credential
    return head(:not_found) unless credential&.document&.attached?

    send_data credential.document.download, **document_options(credential)
  end

  private

  def accessible_credential
    Current.user.profile&.credentials&.find_by(id: params[:id])
  end

  def document_options(credential)
    {
      filename: credential.document.filename.to_s,
      content_type: credential.document.content_type,
      disposition: "attachment",
    }
  end
end
