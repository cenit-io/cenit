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

  # By default all tasks are processed asynchronous, set synchronous_#{task_model_slug} to true to change that behavior.
  # Example
  # synchronous_flow_execution true

  #HTTP Proxy
  http_proxy_address ENV['HTTP-PROXY']

  #HTTP Proxy Port
  http_proxy_port ENV['HTTP-PROXY-PORT']

  #HTTP Proxy User
  http_proxy_user ENV['HTTP-PROXY-USER']

  #HTTP Proxy Password
  http_proxy_password ENV['HTTP-PROXY-PASSWORD']

  excluded_actions ENV['EXCLUDED_ACTIONS']

  maximum_unicorn_consumers((ENV['MAXIMUM_UNICORN_CONSUMERS'] || 3).to_i)

  min_scheduler_interval 60

  scheduler_lookup_interval((ENV['SCHEDULER_LOOKUP_INTERVAL'] || 60).to_i)

  default_delay 30

  delay_tasks ENV['DELAY_TASKS'].to_b

  default_code_theme 'monokai'

  request_timeout ENV['REQUEST_TIMEOUT'] || 300

  using_accounts_dbs ENV['USING_ACCOUNTS_DBS']

  #Max count of tab actions to show before the More Actions tab, if there are more actions to show
  max_tab_actions_count 2

  #Max nested forms count generation for new/update actions
  max_nested_forms 100

  #Max nested forms levels generation for new/update actions
  max_nested_forms_levels 10

  max_handling_schemas 500

  file_stores Cenit::FileStore::LocalDb, Cenit::FileStore::AwsS3Default, Cenit::FileStore::AwsS3

  default_file_store ENV['DEFAULT_FILE_STORE']

  file_stores_roles :super_admin

  aws_s3_bucket_prefix ENV['AWS_S3_BUCKET_PREFIX'] || 'cenit'

  aws_s3_region ENV['AWS_S3_REGION'] || 'us-west-2'

  maximum_task_resumes 500

  maximum_script_execution_resumes 10000

  maximum_cyclic_flow_executions 5

  default_error_notifications_span 1.week

  default_warning_notifications_span 5.days

  default_notice_notifications_span 3.days

  default_info_notifications_span 1.hour

  slack_link ENV['SLACK_INVITATION']

  tenant_creation_disabled((ENV['TENANT_CREATION_DISABLED'] || 'false').to_b)

  storage_chunk_size [
                       [
                         Mongoff::GridFs::FileModel::MINIMUM_CHUNK_SIZE,
                         (ENV['STORAGE_CHUNK_SIZE'] || Mongoff::GridFs::FileModel::MAXIMUM_CHUNK_SIZE).to_i
                       ].max,
                       Mongoff::GridFs::FileModel::MAXIMUM_CHUNK_SIZE
                     ].min

  process_old_notifications((ENV['PROCESS_OLD_NOTIFICATIONS'] || :automatic).to_sym)

  default_auth_token_length(( ENV['DEFAULT_AUTH_TOKEN_LENGTH'] || 60 ).to_i)

  default_oauth_token_length(( ENV['DEFAULT_OAUTH_TOKEN_LENGTH'] || 60 ).to_i)

  delay_time_for_token_refresh(( ENV['DELAY_TIME_FOR_TOKEN_REFRESH'] || 60 ).to_i)
end
