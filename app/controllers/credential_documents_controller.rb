# frozen_string_literal: true

class CredentialDocumentsController < ApplicationController
  def show
    credential = accessible_credential
    return head(:not_found) unless credential&.document&.attached?

    document = credential.document
    send_data document.download,
              filename: document.filename.to_s,
              content_type: document.content_type,
              disposition: "attachment"
  end

  private

  def accessible_credential
    Current.user.profile&.credentials&.find_by(id: params[:id])
  end
end
