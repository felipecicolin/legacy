# frozen_string_literal: true

# Gráfico de barras empilhadas gerado no servidor. Assim a leitura básica não
# depende de JavaScript nem de uma biblioteca externa de gráficos.
class FundraisingTrendChartComponent < ApplicationComponent
  CHANNEL_KEYS = FundraisingChannels::CHANNEL_KEYS
  CHANNEL_CLASSES = {
    one_off: "fill-primary",
    recurring: "fill-accent",
    in_kind: "fill-category-3",
    event_store: "fill-category-4",
  }.freeze
  CHANNEL_LABEL_KEYS = {
    one_off: "fundraising_trend_chart_component.legend.one_off",
    recurring: "fundraising_trend_chart_component.legend.recurring",
    in_kind: "fundraising_trend_chart_component.legend.in_kind",
    event_store: "fundraising_trend_chart_component.legend.event_store",
  }.freeze

  def initialize(points:)
    @points = points
    super()
  end

  def call
    helpers.tag.div(class: "min-w-0") do
      helpers.safe_join([legend, chart])
    end
  end

  private

  def legend
    helpers.tag.ul(class: "flex flex-wrap gap-4 text-label text-muted-foreground") do
      helpers.safe_join(CHANNEL_KEYS.map { |channel| legend_item(channel) })
    end
  end

  def legend_item(channel)
    tag = helpers.tag
    helpers.tag.li(class: "inline-flex items-center gap-2") do
      helpers.safe_join([legend_dot(tag, channel), tag.span(channel_label(channel))])
    end
  end

  def legend_dot(tag, channel)
    tag.span("", class: "h-2 w-2 rounded-full #{CHANNEL_CLASSES.fetch(channel)}", aria: { hidden: true })
  end

  def channel_label(channel) = t(CHANNEL_LABEL_KEYS.fetch(channel))

  def chart
    helpers.tag.svg(**chart_attributes) do
      helpers.safe_join([axis, bars, labels])
    end
  end

  def chart_attributes
    { "viewBox" => "0 0 720 280", class: "h-auto w-full", role: "img",
      aria: { label: t("fundraising_trend_chart_component.aria_label") } }
  end

  def axis
    helpers.tag.line("x1" => 24, "y1" => 220, "x2" => 700, "y2" => 220, class: "stroke-border")
  end

  def bars
    helpers.safe_join(@points.each_with_index.flat_map { |point, index| bar_group(point, index) })
  end

  def bar_group(point, index)
    base_x = 36 + (index * 110)
    state = { height: 0, tags: [] }
    CHANNEL_KEYS.each { |channel| state[:tags] << bar_for(point, channel, base_x, state) }
    state[:tags]
  end

  def bar_for(point, channel, base_x, state)
    height = bar_height(point.amounts.fetch(channel, 0))
    state[:height] += height
    helpers.tag.rect(**bar_attributes(base_x, state[:height], height, channel))
  end

  def bar_attributes(base_x, stack_height, height, channel)
    { "x" => base_x, "y" => 220 - stack_height, "width" => 68, "height" => height,
      class: CHANNEL_CLASSES.fetch(channel) }
  end

  def labels
    helpers.safe_join(@points.each_with_index.map do |point, index|
      helpers.tag.text(point.label, x: 70 + (index * 110), y: 246,
                                    class: "fill-muted-foreground text-label", "text-anchor" => "middle")
    end)
  end

  def bar_height(value)
    maximum = [@points.flat_map { |point| point.amounts.values }.max.to_i, 1].max
    (value.to_f / maximum * 180).round
  end
end
