source "https://rubygems.org"

gem 'parser', path: 'vendor/parser'
# Pin Prism to latest published — Ruby 4.0.1 stdlib has 1.8.0 and
# the parser-side of pattern_matching has had upstream fixes since.
gem 'prism', '~> 1.9'
gem 'profile'
gem 'rake'

# Pure-Ruby stdlib gems — available for require inside Frozone programs
gem 'abbrev'
gem 'base64'
gem 'csv'
gem 'getoptlong'
gem 'logger'
gem 'matrix'
gem 'observer'
gem 'prime'
gem 'psych-pure'

group :test do
  gem 'rspec'
  gem 'mspec'
end

group :development do
  gem 'rubocop'
  gem 'stackprof'
end
