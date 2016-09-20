Gem.loaded_specs['caseflow'].dependencies.each do |d|
  require d.name
end

require "caseflow/version"
require "caseflow/engine"
