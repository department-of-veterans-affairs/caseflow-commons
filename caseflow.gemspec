
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "caseflow/version"

Gem::Specification.new do |spec|
  spec.name          = "caseflow"
  spec.version       = Caseflow::VERSION
  spec.authors       = ["Caseflow"]
  spec.email         = ["caseflowops@va.gov"]

  spec.summary       = "Shared resources for VA Caseflow applications"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "brakeman"
  spec.add_development_dependency "bundler-audit"
  spec.add_development_dependency "danger"
  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "fakeweb"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rainbow"
  spec.add_development_dependency "rake", "~> 12.3"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-rails"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "webmock"

  # Delete after full testing
  # spec.add_runtime_dependency "bourbon", "4.2.7"
  # spec.add_runtime_dependency "neat"

  spec.add_runtime_dependency "rails", ">=4.2.7.1"
  spec.add_runtime_dependency "jquery-rails"
  spec.add_runtime_dependency "redis-namespace"
  spec.add_runtime_dependency "redis-rails"
  # TODO drop d3-rails as Caseflow does not use it?
  spec.add_runtime_dependency "d3-rails"
  spec.add_runtime_dependency "momentjs-rails"

  spec.add_runtime_dependency "aws-sdk", "~> 2.10"
  # Known issue: Must be loaded by Bundler, so include in each app's Gemfile
  # spec.add_runtime_dependency "moment_timezone-rails"
end
