# frozen_string_literal: true

Gem.loaded_specs["caseflow"].runtime_dependencies.each do |d|
  require d.name
end

require "caseflow/version"
require "caseflow/engine"
