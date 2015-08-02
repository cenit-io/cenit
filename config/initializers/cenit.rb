require 'cenit/config'

Cenit.config do

  #Deactivate models on cenit startup
  deactivate_models false

  #Use this option to setup an external service
  service_url 'http://localhost:4567'

  #Home page
  homepage 'www.cenitsass.com'

  #Captcha length
  captcha_length 5

  #Process flow messages asynchronous
  asynchronous_flow_processing false

end