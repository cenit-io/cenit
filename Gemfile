source 'https://rubygems.org'

ruby '2.5.5'
gem 'rails'
gem 'sass-rails'
gem 'uglifier'
gem 'coffee-rails'
gem 'jquery-rails'
gem 'jbuilder'
gem 'devise'
gem 'rabl'
gem 'builder'
gem 'haml-rails'
gem 'figaro'
gem 'unicorn', '4.9.0'
gem 'xmldsig'
gem 'spreadsheet'
gem 'peddler'

group :doc do
  gem 'sdoc', require: false
end

group :development, :test do
  gem 'factory_girl_rails'
  gem 'rspec-rails'
  gem 'rails_layout'
  gem 'ffaker'
  gem 'rubocop', require: false
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'pry-doc'
end

group :test do
  gem 'mongoid-rspec'
  gem 'database_cleaner'
  gem 'capybara'
  gem 'poltergeist'
end

group :production do
  gem 'thin'
  gem 'rails_12factor'
end

gem 'mongoid'
gem 'bson_ext'

gem 'httparty'
gem 'bunny', '~> 2.6'
gem 'json-schema'
gem 'nokogiri'
gem 'cancan'
gem 'rolify'
gem 'rufus-scheduler'
gem 'rubyzip'
gem 'prawn-rails'
gem 'carrierwave-mongoid'
gem 'mini_magick'
gem 'liquid'
gem 'codemirror-rails'
gem 'wannabe_bool'
gem 'parser'
gem 'oauth'

gem 'captcha'
gem "recaptcha", require: "recaptcha/rails"
gem 'httmultiparty'

gem 'oauth2'
gem 'exception_notification'

gem 'mime'
gem 'deface'

gem 'cross_origin', git: 'https://github.com/cenit-io/cross_origin.git'

gem 'lodash-rails'
gem 'identicon'

gem 'language_sniffer'

gem 'cenit-config', git: 'https://github.com/cenit-io/cenit-config.git'
gem 'cenit-multi_tenancy', git: 'https://github.com/cenit-io/cenit-multi_tenancy.git'
gem 'cenit-token', git: 'https://github.com/cenit-io/cenit-token.git'
gem 'cenit-service', git: 'https://github.com/cenit-io/cenit-service.git'

gem 'capataz', git: 'https://github.com/cenit-io/capataz.git'

gem 'rkelly-remix'

gem 'write_xlsx'
gem 'mini_racer'
gem 'ruby-handlebars'

gem 'aws-sdk', '~> 2.10.13'

gem 'net-scp'
gem 'net-sftp'

gem 'mongoid-tracer', git: 'https://github.com/cenit-io/mongoid-tracer.git'
gem 'combine_pdf', '1.0.4'
gem 'kaminari-mongoid'

gem 'redis'
gem 'net-ldap'

gem 'cenit-build_in_apps', git: 'https://github.com/cenit-io/cenit-build_in_apps.git'
gem 'cenit-oauth_app', git: 'https://github.com/cenit-io/cenit-oauth_app.git'
gem 'cenit-open_id', git: 'https://github.com/cenit-io/cenit-open_id.git'
gem 'cenit-admin', git: 'https://github.com/cenit-io/cenit-admin.git'
gem 'cenit-mime', git: 'https://github.com/cenit-io/cenit-mime.git'

custom_gemfile_name = 'custom_Gemfile'

if File.exist?(custom_gemfile_name)
  instance_eval File.read(custom_gemfile_name)
end
