require 'cenit/config'

Cenit.config do

  share_on_github true

  github_shared_collections_home ENV['GITHUB_SHARED_COLLECTIONS_HOME']

  github_shared_collections_user ENV['GITHUB_SHARED_COLLECTIONS_USER']

  github_shared_collections_pass ENV['GITHUB_SHARED_COLLECTIONS_PASS']

  #Deactivate models on cenit startup
  deactivate_models false

  #Use this option to setup an external service
  service_url ENV['SERVICE_URL']

  #Home page
  homepage ENV['HOMEPAGE']

  #Captcha length
  captcha_length 5

  #Process flow messages asynchronous
  asynchronous_flow_execution true

  #Generate data types asynchronous
  asynchronous_data_type_generation true

  #Expand data types asynchronous
  asynchronous_data_type_expansion true

  #oauth2 callback site
  oauth2_callback_site ENV['OAUTH2_CALLBACK_SITE']

  #HTTP Proxy
  http_proxy ENV['HTTP-PROXY']

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
end
