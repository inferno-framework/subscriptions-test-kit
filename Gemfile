# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development, :test do
  gem 'debug'
  gem 'rubocop', '~> 1.56'
  gem 'rubocop-rspec', require: false
  gem "rubocop-rake", "~> 0.6.0"
  gem 'roo', '~> 2.10.1'
end

group :test do
  gem 'database_cleaner-sequel', '~> 1.8'
  gem 'factory_bot', '~> 6.1'
  gem 'rack-test'
  gem 'rspec', '~> 3.10'
  gem 'webmock', '~> 3.11'
end
