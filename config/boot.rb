# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

# Allow early compatibility shims (for gem requires) before Bundler eager-requires gems.
lib_path = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
