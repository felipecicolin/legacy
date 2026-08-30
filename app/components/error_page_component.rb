# frozen_string_literal: true

class ErrorPageComponent < ApplicationComponent
  STATUSES = {
    forbidden: { code: 403, icon: "alert-octagon" },
    not_found: { code: 404, icon: "search" },
    unprocessable_entity: { code: 422, icon: "alert-triangle" },
    internal_server_error: { code: 500, icon: "alert-octagon" },
  }.freeze
  Attrs = Data.define(:status, :classes)
  private_constant :Attrs

  def initialize(status:, classes: nil)
    super()
    validate_inclusion!(:status, status, STATUSES.keys)
    @attrs = Attrs.new(status:, classes:)
  end

  def computed_classes
    class_merge("mx-auto w-full max-w-2xl", @attrs.classes)
  end

  def icon
    status_config.fetch(:icon)
  end

  def status_code
    status_config.fetch(:code)
  end

  def title
    {
      forbidden: t("error_page_component.forbidden.title"),
      internal_server_error: t("error_page_component.internal_server_error.title"),
      not_found: t("error_page_component.not_found.title"),
      unprocessable_entity: t("error_page_component.unprocessable_entity.title"),
    }.fetch(@attrs.status)
  end

  def message
    {
      forbidden: t("error_page_component.forbidden.message"),
      internal_server_error: t("error_page_component.internal_server_error.message"),
      not_found: t("error_page_component.not_found.message"),
      unprocessable_entity: t("error_page_component.unprocessable_entity.message"),
    }.fetch(@attrs.status)
  end

  def action_path
    helpers.root_path
  end

  private

  def status_config
    STATUSES.fetch(@attrs.status)
  end
end
