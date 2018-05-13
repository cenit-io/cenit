//= require 'cenit/home/owl.carousel'
//=  require 'rails_admin/custom/cenit'
//=  require 'cenit/home/home'

$(document).on('rails_admin.dom_ready', function () {
    template_engine.initModule();
    cenit.initModule();
});
