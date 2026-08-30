# frozen_string_literal: true

class TableComponent < ApplicationComponent
  ALIGNMENTS = %i[left center right].freeze
  DIRECTIONS = %w[ascending descending].freeze
  ALIGNMENT_CLASSES = {
    left: "text-left",
    center: "text-center",
    right: "font-mono text-right",
  }.freeze

  class Column < ViewComponent::Base
    attr_reader :header, :align, :sort

    def initialize(header:, align:, sort:, block:)
      super()
      @header = header
      @align = align
      @sort = sort
      @block = block
    end

    def value(row)
      @block.call(row)
    end

    def direction
      candidate = sort.is_a?(Hash) ? sort[:direction] : sort
      value = candidate.to_s
      return value if TableComponent::DIRECTIONS.include?(value)

      nil
    end

    def href
      return sort[:href] if sort.is_a?(Hash)
      return sort unless TableComponent::DIRECTIONS.include?(sort.to_s)

      nil
    end
  end
  private_constant :Column

  renders_many :columns, lambda { |header:, align: :left, sort: nil, &block|
    normalized_align = align.to_sym
    validate_inclusion!(:align, normalized_align, ALIGNMENTS)
    Column.new(header: header, align: normalized_align, sort: sort, block: block)
  }

  def initialize(rows:, caption:, **html_options)
    @rows = rows
    @caption = caption
    super(**html_options)
  end

  def html_attributes
    html_options.merge(class: class_merge("min-w-0", html_options[:class]))
  end

  def empty_state?
    @rows.empty?
  end

  def cell_classes(column)
    class_merge("px-4 py-4 align-top text-body", ALIGNMENT_CLASSES.fetch(column.align))
  end

  def header_attributes(column)
    attributes = { scope: "col", class: cell_classes(column) }
    return attributes unless column.direction

    attributes.merge(aria: { sort: column.direction })
  end

  def column_header(column)
    return column.header unless column.href

    sorted_header(column)
  end

  def sorted_header(column)
    helpers.link_to(column.header, column.href, data: sorting_data, class: "underline-offset-4 hover:underline")
  end

  def column_value(column, row)
    column.value(row)
  end

  attr_reader :caption

  private

  def sorting_data
    html_options.fetch(:data, {}).to_h
  end
end
