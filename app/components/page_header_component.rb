# frozen_string_literal: true

class PageHeaderComponent < ApplicationComponent
  renders_one :actions
  renders_many :breadcrumbs, ->(label:, href: nil) { breadcrumb_item(label, href) }

  def initialize(title:, subtitle: nil, **html_options)
    @title = title
    @subtitle = subtitle
    super(**html_options)
  end

  def html_attributes
    html_options.merge(class: computed_classes)
  end

  def computed_classes
    class_merge("col-span-full mb-6 min-w-0", html_options[:class])
  end

  attr_reader :title, :subtitle

  private

  def breadcrumb_item(label, href)
    content = breadcrumb_content(label, href)
    helpers.tag.li(content, class: "inline-flex items-center")
  end

  def breadcrumb_content(label, href)
    return helpers.link_to(label, href, class: "text-muted-foreground hover:text-foreground") if href.present?

    helpers.tag.span(label, class: "text-foreground")
  end
end
