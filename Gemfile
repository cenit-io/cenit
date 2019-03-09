source 'https://rubygems.org'

ruby '2.3.0'
gem 'rails'
gem 'sass-rails'
gem 'uglifier'
gem 'coffee-rails'
gem 'jquery-rails'
gem 'bootstrap-sass'
#gem 'turbolinks'
gem 'therubyracer', platforms: :ruby
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

group :development do
  gem 'capistrano'
  gem 'capistrano-unicorn-nginx'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-rails-console'
  gem 'capistrano-rvm'
end

group :development, :test do
  gem 'factory_girl_rails'
  gem 'rspec-rails'
  gem 'rails_layout'
  gem 'ffaker'
#  gem 'rubocop', '0.49.0'
end

group :test do
  gem 'mongoid-rspec'
  gem 'database_cleaner'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'simplecov'
  gem 'coveralls'
  gem 'poltergeist'
end

group :production do
  gem 'thin'
  gem 'rails_12factor'
end

gem 'mongoid'
gem 'bson_ext'
gem 'rails_admin', '~> 1.0.0'

# charts
gem 'rails_admin_dynamic_charts', git: 'https://github.com/openjaf/rails_admin_dynamic_charts.git'
gem 'chartkick'
gem 'descriptive_statistics'

gem 'httparty'
gem 'bunny'
gem 'json-schema'
gem 'nokogiri'
gem 'cancan'
gem 'rolify'
gem 'rufus-scheduler'
gem 'rubyzip'
gem 'prawn-rails', '0.1.1'
gem 'prawn-qrcode', '0.2.2.1'
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
gem 'deface'

gem 'cross_origin', git: 'https://github.com/macarci/cross_origin.git'

gem 'lodash-rails'
gem 'identicon'

gem 'language_sniffer'

gem 'cenit-config', git: 'https://github.com/cenit-io/cenit-config.git'
gem 'cenit-multi_tenancy', git: 'https://github.com/cenit-io/cenit-multi_tenancy.git'
gem 'cenit-token', git: 'https://github.com/cenit-io/cenit-token.git'
gem 'cenit-service', git: 'https://github.com/cenit-io/cenit-service.git'
gem 'cenit-home', git: 'https://github.com/cenit-io/cenit-home.git'

gem 'capataz', git: 'https://github.com/macarci/capataz.git'

gem 'rkelly-remix'

gem 'write_xlsx'
gem 'handlebars'
gem 'wicked_pdf'
gem 'wkhtmltopdf-binary'
gem 'rmagick', '2.15.4'
gem 'pdfkit', '0.8.2'
gem 'imgkit', '1.6.1'
gem 'origami', git: 'https://github.com/mobmewireless/origami-pdf.git'

gem 'aws-sdk', '~> 2.10.13'

gem 'net-scp'
gem 'net-sftp'

gem 'mongoid-tracer', git: 'https://github.com/macarci/mongoid-tracer.git'
gem 'diffy'

gem 'pdf-forms', '~> 1.1', '>= 1.1.1'
gem 'combine_pdf', '1.0.4'

custom_gemfile_name = 'custom_Gemfile'

if File.exist?(custom_gemfile_name)
  instance_eval File.read(custom_gemfile_name)
end
