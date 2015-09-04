require 'cenit/config'

Cenit.config do

  #Deactivate models on cenit startup
  deactivate_models true

  #Use this option to setup an external service
  #service_url 'http://service.cenithub.com' 
  service_url 'http://service.cenithub.com'

  #Home page
  homepage 'www.cenitsass.com'

  #Captcha length
  captcha_length 5

  #Process flow messages asynchronous
  asynchronous_flow_processing false

  #oauth2 callback site
  oauth2_callback_site ENV['CALLBACK_SITE']

end
