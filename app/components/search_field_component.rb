# frozen_string_literal: true

class SearchFieldComponent < ApplicationComponent
  Attrs = Data.define(:url, :frame, :attribute, :value)
  private_constant :Attrs

  def initialize(url:, frame: nil, attribute: :query, value: nil, **html_options)
    @attrs = Attrs.new(url: url, frame: frame, attribute: attribute, value: value)
    super(**html_options)
  end

  def html_attributes
    html_options.merge(class: class_merge("w-full", html_options[:class]))
  end

  def form_data
    @attrs.frame.present? ? { turbo_frame: @attrs.frame } : {}
  end

  def clear_data
    form_data
  end

  delegate :url, :frame, :attribute, :value, to: :@attrs
end
