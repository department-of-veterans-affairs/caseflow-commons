source "https://rubygems.org"

# Specify your gem's dependencies in caseflow.gemspec
gemspec

# Until it's understood why a ref to "uswds-rails" in the gemspec fails...
gem "uswds-rails", git: "https://github.com/18F/uswds-rails-gem.git"

group :development, :test do
  gem "brakeman"
  gem "bundler-audit"
  gem "danger"
  gem "pry"
  gem "redis-namespace"
  gem "redis-rails"
  gem "rubocop", "~> 0.52.1", require: false
  gem "scss_lint"
  gem "timecop"
end
