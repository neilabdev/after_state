# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in after_state.gemspec
gemspec

gem "rake", "~> 13.0"
gem "rspec", "~> 3.0"
gem "standard", "~> 1.3"

group :development, :test do
  gem 'rspec-rails'
  gem 'logger'
  gem 'ostruct'
end

group :test do
  gem 'activerecord'
  gem "cgi"
end