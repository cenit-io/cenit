require 'cenit/config'

Cenit.config do

  #Deactivate models on cenit startup
  deactivate_models true

  #Use this option to setup an external service
  service_url  ENV['SERVICE_URL']

  #Home page
  homepage ENV['HOMEPAGE']

  #Captcha length
  captcha_length 5

  #Process flow messages asynchronous
  asynchronous_flow_execution true

  #Generate data types asynchronous
  asynchronous_data_type_generation true

  #oauth2 callback site
  oauth2_callback_site ENV['OAUTH2_CALLBACK_SITE']

  #HTTP Proxy
  http_proxy ENV['HTTP-PROXY']

  #Hide navigation admin pane
  hide_admin_navigation false

end
