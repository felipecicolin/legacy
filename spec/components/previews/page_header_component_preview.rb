# frozen_string_literal: true

class PageHeaderComponentPreview < ViewComponent::Preview
  def playground
    render(PageHeaderComponent.new(title: "Obras", subtitle: "Acompanhe o avanço de cada projeto."))
  end

  def with_breadcrumbs_and_actions
    render(PageHeaderComponent.new(title: "Detalhes da obra")) do |header|
      header.with_breadcrumb(label: "Obras", href: "#")
      header.with_breadcrumb(label: "Detalhes")
      header.with_actions do
        render(ButtonComponent.new(label: "Editar obra", variant: :outline, href: "#"))
      end
    end
  end
end
