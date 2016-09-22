require 'cenit/cenit'

Cenit.config do

  share_on_github false

  github_shared_collections_home ENV['GITHUB_SHARED_COLLECTIONS_HOME']

  github_shared_collections_user ENV['GITHUB_SHARED_COLLECTIONS_USER']

  github_shared_collections_pass ENV['GITHUB_SHARED_COLLECTIONS_PASS']

  #The path for OAuth 2.0 actions
  oauth_path '/oauth'

  #Set this option to :embedded to mount the cenit-oauth Token End Point
  oauth_token_end_point ENV['OAUTH_TOKEN_END_POINT']

  #Use this option to setup an external service
  service_url ENV['SERVICE_URL']

  #If an external service is not configured then mount the cenit-service engine in this path
  service_path '/service'

  #The path tha serves schemas on the service URL
  schema_service_path '/schema'

  #Home page
  homepage ENV['HOMEPAGE']

  #Captcha length
  captcha_length 5

  #Process flow messages asynchronous
  asynchronous_flow_execution true

  #Generate data types asynchronous
  asynchronous_data_type_generation true

  #Execute translations asynchronous
  asynchronous_translation true

  #Execute data import asynchronous
  asynchronous_data_import true

  #Execute schemas import asynchronous
  asynchronous_schemas_import true

  #Expand data types asynchronous
  asynchronous_data_type_expansion true

  #Delete records asynchronous
  asynchronous_deletion true

  #Execute algorithms asynchronous
  asynchronous_algorithm_execution true

  #Execute scripts asynchronous
  asynchronous_script_execution true

  #Process webhook submits asynchronous
  asynchronous_submission true

  #Process pull imports asynchronous
  asynchronous_pull_import true

  #Process shared collection pulls asynchronous
  asynchronous_shared_collection_pull true

  #oauth2 callback site
  oauth2_callback_site ENV['OAUTH2_CALLBACK_SITE']

  #HTTP Proxy
  http_proxy_address ENV['HTTP-PROXY']

  #Hide navigation admin pane
  hide_admin_navigation false

  #HTTP Proxy Port
  http_proxy_port ENV['HTTP-PROXY-PORT']

  #HTTP Proxy User
  http_proxy_user ENV['HTTP-PROXY-USER']

  #HTTP Proxy Password
  http_proxy_password ENV['HTTP-PROXY-PASSWORD']

  excluded_actions ENV['EXCLUDED_ACTIONS']

  multiple_unicorn_consumers true

  min_scheduler_interval 60

  scheduler_lookup_interval 60

  default_delay 30

  rabbit_mq_user ENV['RABBIT_MQ_USER']

  rabbit_mq_password ENV['RABBIT_MQ_PASSWORD']

  default_code_theme 'monokai'
end
