# frozen_string_literal: true

# Percentual limitado entre zero e cem para comparações de valor e meta.
class SharePercentage
  def self.call(value, target)
    return 0 if target.to_i.zero?

    ((value.to_f / target) * 100).clamp(0, 100).round
  end
end
