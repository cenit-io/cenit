# This file is used by Rack-based servers to start the application.

# Improves site's stability by avoiding unexpected memory exhaustion at the application nodes
# https://www.digitalocean.com/community/tutorials/how-to-optimize-unicorn-workers-in-a-ruby-on-rails-app
#
# --- Start of unicorn worker killer code ---

if ENV['RAILS_ENV'] == 'production' 
  require 'unicorn/worker_killer'

  max_request_min =  500
  max_request_max =  600

  # Max requests per worker
  use Unicorn::WorkerKiller::MaxRequests, max_request_min, max_request_max

  min_limit = (240) * (1024**2)
  max_limit = (260) * (1024**2)

  # Max memory size (RSS) per worker
  # The actual limit is a rand(min_limit, max_limit)
  # https://github.com/kzk/unicorn-worker-killer
  use Unicorn::WorkerKiller::Oom, min_limit, max_limit
end

# --- End of unicorn worker killer code ---

require ::File.expand_path('../config/environment',  __FILE__)
run Rails.application
