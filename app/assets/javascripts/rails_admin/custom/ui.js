//= require 'home/owl.carousel'
//=  require 'rails_admin/custom/cenit'
//=  require 'home/home'

$(document).on('rails_admin.dom_ready', function () {
    template_engine.initModule();
    cenit.initModule();
});
