#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "simplecov"
require "simplecov_json_formatter"

resultset_paths = Dir.glob(File.expand_path("../tmp/coverage/coverage-*/.resultset.json", __dir__))
local_resultset = File.expand_path("../coverage/.resultset.json", __dir__)
resultset_paths = [local_resultset] if resultset_paths.empty? && File.exist?(local_resultset)

abort("No coverage resultsets found") if resultset_paths.empty?

puts "Collating #{resultset_paths.size} coverage resultset(s):"
resultset_paths.each { |path| puts "  - #{path}" }

SimpleCov.collate(resultset_paths, "rails") do
  enable_coverage :branch
  minimum_coverage line: 100.0, branch: 100.0
  skip "lib/i18n_tasks/"
  formatter SimpleCov::Formatter::JSONFormatter
end
