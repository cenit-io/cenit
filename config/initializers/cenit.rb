#rails_admin-1.0 ready

require 'cenit/cenit'

Cenit.config do

  share_on_github false

  github_shared_collections_home ENV['GITHUB_SHARED_COLLECTIONS_HOME']

  github_shared_collections_user ENV['GITHUB_SHARED_COLLECTIONS_USER']

  github_shared_collections_pass ENV['GITHUB_SHARED_COLLECTIONS_PASS']

  #The path for OAuth 2.0 actions
  oauth_path '/oauth'

  #Set this option to :embedded to mount the cenit-oauth Token End Point
  oauth_token_end_point ENV['OAUTH_TOKEN_END_POINT'] || :embedded

  #Use this option to setup an external service
  service_url ENV['SERVICE_URL']

  #If an external service is not configured then mount the cenit-service engine in this path
  service_path '/service'

  #The path tha serves schemas on the service URL
  schema_service_path '/schema'

  #Home page
  homepage ENV['HOMEPAGE'] || 'http://127.0.0.1:3000'

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

  #Process API pulls asynchronous
  asynchronous_api_pull true

  #Performs crossing origins asynchronous
  asynchronous_crossing true

  #Performs pushes asynchronous
  asynchronous_push true

  #Performs chart rendering asynchronous
  asynchronous_chart_rendering true

  #Performs namespace collection asynchronous
  asynchronous_namespace_collection true

  #Performs notification execution asynchronous
  asynchronous_notification_execution true

  #Performs file store migrations asynchronous
  asynchronous_file_store_migration true

  #oauth2 callback site
  oauth2_callback_site ENV['OAUTH2_CALLBACK_SITE'] || homepage

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

  request_timeout 300

  ecommerce_data_types Ecommerce: %w(customer.json product.json inventory.json cart.json order.json shipment.json)

  email_data_type MIME: 'Message'

  using_accounts_dbs ENV['USING_ACCOUNTS_DBS']

  #Max count of tab actions to show before the More Actions tab, if there are more actions to show
  max_tab_actions_count 2

  #Max nested forms count generation for new/update actions
  max_nested_forms 100

  #Max nested forms levels generation for new/update actions
  max_nested_forms_levels 10

  max_handing_schemas 500

  jupyter_notebooks (ENV['JUPYTER_NOTEBOOKS'] || 'false').to_b

  jupyter_notebooks_url ENV['JUPYTER_NOTEBOOKS_URL'] || 'http://127.0.0.1:8888'

  chart_data_request_interval 3000

  file_stores Cenit::FileStore::LocalDb, Cenit::FileStore::AwsS3

  file_stores_roles :super_admin

  aws_s3_bucket_prefix ENV['AWS_S3_BUCKET_PREFIX'] || 'cenit'

  aws_s3_region ENV['AWS_S3_REGION'] || 'us-west-2'
end
