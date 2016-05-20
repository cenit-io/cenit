// require rails_admin/d3
// require rails_admin/highcharts
//= require rails_admin/triggers-box
//= require rails_admin/test-flow-transformation
//= require rails_admin/highlight_js/highlight.pack.js

$(document).on('rails_admin.dom_ready', function() {
  $('pre code').each(function(i, block) {
     hljs.highlightBlock(block);
   });
});

$(function(){
    if ($(window).width() > 767) {
        $("#wrapper").addClass('toggled');
        $("#sidebar-toggle").addClass('toggled');
    }

    $("#sidebar-toggle").click(function(e) {
        e.preventDefault();
        $("#wrapper").toggleClass("toggled");
        $(this).toggleClass("toggled");
    });

    $('#main-accordion').find('.panel-heading a.panel-title').click(function(){
        var parent = $(this).parent().parent();
        $(parent).toggleClass('active');
        if ($(parent).hasClass('active'))
            $(parent).siblings().each(function () {
                $(this).removeClass('active');
            });
    });
});

$(function () {
    $('#take-tour').click(function(e){
        e.preventDefault();
        var tour = new Tour({
            name: 'anonymous',
            steps: [
                {
                    title: "Welcome to cenit.io!",
                    content: "Thanks for visiting us! Click 'Next' to start the tour.",
                    orphan: true
                },
                {
                    title: "Browse our Collections",
                    content: "Install any available collection in the blink of an eye, and create your own",
                    element: "#main-collections",
                    placement: "right"
                },
                {
                    title: "Define and store data",
                    content: "Create your schemas and data types",
                    element: "#main-data",
                    placement: "right"
                },
                {
                    title: "Setup your endpoints",
                    content: "Register connections and webhooks",
                    element: "#main-api-connectors",
                    placement: "right"
                },
                {
                    title: "Transform and dispatch",
                    content: "Send your data away or pull it from a remote endpoint or simply translate it from one data type to another",
                    element: "#main-workflows",
                    placement: "right"
                },
                {
                    title: "Safety first",
                    content: "Control who may access your stuff, and define hoy you access other's",
                    element: "#main-security",
                    placement: "right"
                },
                {
                    title: "Monitoring",
                    content: "Consult the status of every action",
                    element: "#main-monitors",
                    placement: "right"
                },
                {
                    title: "Check the Dashboard",
                    content: "All models are there",
                    element: ".dashboard_root_link",
                    placement: "bottom"
                },
                {
                    title: "Tasks",
                    content: "Check your tasks",
                    element: "#action-tasks",
                    placement: "bottom"
                },
                {
                    title: "Authentications",
                    content: "Authentications here",
                    element: "#action-auth",
                    placement: "bottom"
                },
                {
                    title: "Get notified",
                    content: "Different kinds of notifications",
                    element: "#action-notify",
                    placement: "bottom"
                }
            ]});
// Initialize the tour
        tour.init();

// Start the tour
        tour.start(true);
    });
});
