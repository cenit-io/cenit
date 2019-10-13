source 'https://rubygems.org'

ruby '2.5.5'
gem 'rails'
gem 'sass-rails'
gem 'uglifier'
gem 'coffee-rails'
gem 'jquery-rails'
gem 'bootstrap-sass'
gem 'jbuilder'
gem 'devise', git: 'https://github.com/plataformatec/devise.git', branch: '4-0-stable'
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

gem 'mongo', '~> 2.3.1'
gem 'mongoid'
gem 'bson_ext'
gem 'rails_admin', '~> 2.0.0'

gem 'httparty'
gem 'bunny', '~> 2.6'
gem 'json-schema'
gem 'nokogiri'
gem 'cancan'
gem 'rolify'
gem 'rufus-scheduler'
gem 'rubyzip'
gem 'carrierwave-mongoid'
gem 'mini_magick'
gem 'liquid'
gem 'codemirror-rails'
gem 'wannabe_bool'
gem 'parser'
gem 'oauth'
gem 'bootstrap-wysihtml5-rails', '> 0.3.1.24'

gem 'captcha'
gem "recaptcha", require: "recaptcha/rails"
gem 'httmultiparty'

gem 'oauth2'
gem 'exception_notification'

gem 'mime'
# //gem 'deface', git: 'https://github.com/spree/deface.git'

# TODO temporal branch, review the change
gem 'cross_origin', git: 'https://github.com/cenit-io/cross_origin.git', branch: 'temp_change'

gem 'lodash-rails'
gem 'identicon'

gem 'language_sniffer'

gem 'cenit-config', git: 'https://github.com/cenit-io/cenit-config.git'
gem 'cenit-multi_tenancy', git: 'https://github.com/cenit-io/cenit-multi_tenancy.git', branch: 'mongo_gem_2_3_1'
gem 'cenit-token', git: 'https://github.com/cenit-io/cenit-token.git'
# gem 'cenit-service', git: 'https://github.com/cenit-io/cenit-service.git'

gem 'capataz', git: 'https://github.com/macarci/capataz.git'

gem 'rkelly-remix'

gem 'write_xlsx'
gem 'handlebars'

gem 'aws-sdk', '~> 2.10.13'

gem 'net-scp'
gem 'net-sftp'

gem 'mongoid-tracer', git: 'https://github.com/macarci/mongoid-tracer.git'
gem 'diffy'
gem 'combine_pdf', '1.0.4'
gem 'kaminari-mongoid'

gem 'redis'

custom_gemfile_name = 'custom_Gemfile'

if File.exist?(custom_gemfile_name)
  instance_eval File.read(custom_gemfile_name)
end
