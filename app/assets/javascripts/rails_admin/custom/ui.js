// require rails_admin/d3
// require rails_admin/highcharts
//= require rails_admin/utils
//= require rails_admin/toggle-origin.js
//= require rails_admin/bootstrap-tour.min
//= require rails_admin/triggers-box
//= require rails_admin/highlight_js/highlight.pack.js
//= require rails_admin/handlers
//= require rails_admin/highcharts
//= require rails_admin/chartkick
//= require lodash.min
//= require rails_admin/select2.full.min

$(document).on('rails_admin.dom_ready', function () {
    $('pre code').each(function (i, block) {
        hljs.highlightBlock(block);
    });
    handlerInit();
    if ($(window).width() > 767) {
        $("#wrapper").addClass('toggled');
        $("#sidebar-toggle").addClass('toggled');
    }
    if (getAbsolute()) {
        $(".social-links").addClass("absolute");
    }
    registerEvents();
});

// Vars
var
    tour_steps = {
        'welcome': {
            title: "Welcome to cenit.io!",
            content: "Thanks for visiting us! Click 'Next' to start the tour.",
            orphan: true,
            onNext: function () {
                openNavigator();
            }
        },
        'collections': {
            title: "Browse our Collections",
            content: "Install any available collection in the blink of an eye, and create your own",
            element: "#g_integrations",
            placement: "top",
            onShow: function () {
                that = this.element;
                toggle_collapse(that);
                openNavigator();
            },
            onHide: function () {
                that = this.element;
                toggle_collapse(that);
            }
        },
        'data': {
            title: "Define data",
            content: "Create your schemas and data types",
            element: "#l_definitions",
            placement: "right",
            onShow: function () {
                that = this.element;
                toggle_collapse(that);
                openNavigator();
            },
            onHide: function () {
                that = this.element;
                toggle_collapse(that);
            }
        },
        'store': {
            title: "Store data",
            content: "Store your objects",
            element: "#l_objects",
            placement: "right",
            onShow: function () {
                that = this.element;
                toggle_collapse(that);
                openNavigator();
            },
            onHide: function () {
                that = this.element;
                toggle_collapse(that);
            }
        },
        'connections': {
            title: "Setup your endpoints",
            content: "Register connections and webhooks",
            element: "#l_connectors",
            placement: "left",
            onShow: function () {
                that = this.element;
                toggle_collapse(that);
                openNavigator();
            },
            onHide: function () {
                that = this.element;
                toggle_collapse(that);
            }
        },
        'transforms': {
            title: "Transform and dispatch",
            content: "Send your data away or pull it from a remote endpoint or simply translate it from one data type to another",
            element: "#g_transforms",
            placement: "right",
            onShow: function () {
                that = this.element;
                toggle_collapse(that);
                openNavigator();
            },
            onHide: function () {
                that = this.element;
                toggle_collapse(that);
            }

        },
        'security': {
            title: "Safety first",
            content: "Control who may access your stuff, and define how you access other's",
            element: "#l_security",
            placement: "left",
            onShow: function () {
                that = this.element;
                toggle_collapse(that);
                openNavigator();
            },
            onHide: function () {
                that = this.element;
                toggle_collapse(that);
            }
        },
        'task': {
            title: "Tasks",
            content: "Check your tasks",
            element: "#action-tasks",
            placement: "bottom"
        },
        'authentications': {
            title: "Authentications",
            content: "Authentications here",
            element: "#action-auth",
            placement: "bottom"
        },
        'notifications': {
            title: "Get notified",
            content: "Different kinds of notifications",
            element: "#action-notify",
            placement: "bottom"
        },
        'rest_apis': {
            title: "REST API",
            content: "Get help to use resources throw REST API",
            element: "#rest-api .btn-primary",
            placement: "left",
            onShow: function () {
                $('#nav-drawer').removeClass('open');
            },
            onHide: function () {
                $('#nav-drawer').addClass('open');
            }
        },
        'services': {
            title: "Enjoy our Services",
            content: "Try our services",
            element: "#services_title",
            placement: "top"
        },
        'try': {
            title: "Try it free",
            content: "Try it free to know more about cenit.io",
            element: "#sign-in-link",
            placement: "left",
            onShow: function () {
                that = this.element;
                toggle_collapse(that);
                if (!$("sign-drawer").hasClass('open')) {
                    $('#sign-in-link').trigger('click');
                }
            }
        }
    },
    anonymous_tour = new Tour({
        name: 'anonymous',
        steps: [
            tour_steps.welcome,
            tour_steps.collections,
            tour_steps.data,
            tour_steps.store,
            tour_steps.connections,
            tour_steps.transforms,
            tour_steps.security,
            tour_steps.try
        ]
    }),
    anonymous_tour_at_home = new Tour({
        name: 'anonymous_at_home',
        steps: [
            tour_steps.welcome,
            tour_steps.collections,
            tour_steps.data,
            tour_steps.store,
            tour_steps.connections,
            tour_steps.transforms,
            tour_steps.security,
            tour_steps.try,
            tour_steps.services
        ]
    }),
    user_tour_at_home = new Tour({
        name: 'user_at_home',
        steps: [
            tour_steps.welcome,
            tour_steps.collections,
            tour_steps.data,
            tour_steps.store,
            tour_steps.connections,
            tour_steps.transforms,
            tour_steps.security,
            tour_steps.task,
            tour_steps.authentications,
            tour_steps.notifications,
            tour_steps.services
        ]
    }),
    user_tour = new Tour({
        name: 'user',
        steps: [
            tour_steps.welcome,
            tour_steps.collections,
            tour_steps.data,
            tour_steps.store,
            tour_steps.connections,
            tour_steps.transforms,
            tour_steps.security,
            tour_steps.task,
            tour_steps.authentications,
            tour_steps.notifications,
            tour_steps.rest_apis
        ]
    });

// Functions

function openSigInSideBar() {
    $("#sign-drawer").toggleClass('open');
    // $(this).toggleClass("toggled");

    $("#nav-drawer").removeClass('open');
    $("#nav-drawer-toggle").removeClass("toggled")
}
function getAbsolute() {
    var outer = $("#nav-drawer").height();
    var inner = $("#nav-links").height() + $("#social-links").height();

    return outer > inner;
}
function openNavigator() {
    var $subdomain_panel;
    if ($('#main-dashboard').length == 0) {
        $subdomain_panel = $('#subdomain-panel');
        if ($subdomain_panel.hasClass('collapsed')) {
            $("#subdomain-toggle").trigger('click');
        }
    }
}
function toggle_collapse(id) {
    $('.panel-collapse', id).first().collapse('toggle');
    $(id).toggleClass('active');
}
function filterTenants(text) {
    var i, t, results = [];
    for (i = 0; i < tenants.length; i++) {
        t = tenants[i];
        if (t['name'].match(text) != null) {
            results.push(t);
        }
    }
    return results;
}
function load_tenant_list(tenants_list) {
    tenants = tenants_list;
    var i;
    for (i = 0; i < tenants.length; i++) {
        tenants[i] = JSON.parse(tenants[i]);
    }
}
function render_graphic($form, selector) {
    $.ajax({
        url: $form.attr('action'),
        cache: false,
        method: "POST",
        data: {},
        beforeSend: function () {
            console.log('Loading graphics');
            $(selector).html('Loading graphics');
        },
        success: function (data) {
            $(selector).html(data);
        },
        error: function (data) {
            console.log('Error: Loading graphics: ' + data);
        }
    });
}
function registerEvents() {

    $('#take-tour').click(function (e) {
        e.preventDefault();
        var $this = $(this),
            anonymous = $this.attr('data-anonymous'),
            dashboard_root = $this.attr('data-dashboard-root');
        if (anonymous == 'true') {
            if (dashboard_root == 'true') {
                startTour(anonymous_tour_at_home)

            } else {
                startTour(anonymous_tour)
            }
        }
        else {
            if (dashboard_root == 'true') {
                startTour(user_tour_at_home)
            } else {
                startTour(user_tour)
            }
        }

    });

    $('a#contact_us').click(function (e) {
        e.preventDefault();
        $('div#contact_us').modal({
            keyboard: true,
            backdrop: true,
            show: true
        })
    });

    $('.contact-modal').click(function (e) {
        e.preventDefault();
        $('div#contact_us').modal({
            keyboard: true,
            backdrop: true,
            show: true
        })
    });

    $(".soc-btn").on("click", function (ev) {
        $(this).addClass("selected");
        $(this).siblings().addClass("unused");

        var overlay = $('<div id="modal-overlay"></div>');
        overlay.appendTo(document.body);
    });

    $('#show_tenant_menu').on('click', function (e) {
        var $menu = $('#tenant-menu');
        if ($menu.css('display') == 'none') {
            $menu.css('display', 'block');
        }
        else {
            $menu.css('display', 'none');
        }
    });

    $('*').on('click', function (event) {
        var $target = $(event.target);
        if (($target.parents('#dropdown-tenants').length == 0) && ($target.attr('id') != "tenant_name")) {
            $('#tenant-menu').css('display', 'none');
        }
        if (($target.parents('#subdomain-toggle').length == 0) && ($target.parents('#subdomain-panel').length == 0) && ($target.attr('id') != "subdomain-toggle") && ($target.parents('.popover-navigation').length == 0)) {
            if (!$('#subdomain-panel').hasClass('collapsed')) {
                $('#subdomain-panel').addClass('collapsed');
                $('#subdomain-toggle').toggleClass("toggled");
            }
        }
    });

    $('#search_tenant').on('keydown', function (e) {
        var filtered_tenants,
            tenants_to_html = function (tenants_list) {
                var i, t, html = '';
                for (i = 0; i < tenants_list.length; i++) {
                    t = tenants_list[i];
                    html += '<li><a href="' + t['url'] + '">' + t['name'] + '</a></li>'
                }
                return html;
            };
        var count_letter = $(this).val().length;
        if (count_letter > 1) {
            filtered_tenants = filterTenants($(this).val());
        }
        else {
            filtered_tenants = tenants
        }
        $('.dropdown-menu .tenants').html(tenants_to_html(filtered_tenants));
    });

    $("#view_graphic").click(function (e) {
        e.preventDefault();
        $('[name="enable_chart"]').val('true');
    });

    $("#sidebar-toggle").click(function (e) {
        e.preventDefault();

        var $content_wrapper = $("#content-wrapper"),
            $nav_icon = $(this).siblings().find('.nav-icon'),
            $wrapper = $("#wrapper"),
            $accordion = $('#main-accordion');

        $wrapper.toggleClass("toggled");
        $(this).toggleClass("toggled");

        if ($("#sidebar-wrapper").css('width') == "55px") {
            $nav_icon.removeClass('no-view');

        } else {
            if ($wrapper.hasClass("toggled")) {
                $nav_icon.removeClass('no-view');
                $content_wrapper.css('width', 'calc(100% - 250px)');

            } else {
                $nav_icon.addClass('no-view');
                $content_wrapper.css('width', 'calc(100% - 55px)');

            }
            $accordion.find('.panel-default').removeClass('active');
            $accordion.find('.panel-collapse').removeClass('in')
        }
    });

    $("#subdomain-toggle").off('click').on('click', function (e) {
        e.stopPropagation();
        e.stopImmediatePropagation();
        $("#subdomain-panel").toggleClass("collapsed");
        var $subdomain = $(e.target).parents().find('#subdomain-toggle');
        $subdomain.toggleClass("toggled");
    });

    var $main_accordion = $('#main-accordion');

    $main_accordion.find('.panel-heading a.panel-title').click(function () {
        var parent = $(this).parent().parent();
        $(parent).toggleClass('active');
        if ($(parent).hasClass('active'))
            $(parent).siblings().each(function () {
                $(this).removeClass('active');
            });
    });

    $main_accordion.find('a[data-toggle="collapse"]').on('click', function () {
        var $conten_wraper = $("#content-wrapper"),
            $wrapper = $("#wrapper");
        if (!$wrapper.hasClass("toggled")) {
            $wrapper.addClass("toggled");
            $conten_wraper.css('width', 'calc(100% - 250px)');
        }
    });

    $("#nav-drawer-toggle").click(function (e) {
        e.preventDefault();
        $("#nav-drawer").toggleClass('open');
        $(this).toggleClass("toggled");

        $("#sign-drawer").removeClass('open');
    });

    $("#sign-in-link").click(function (e) {
        e.preventDefault();
        openSigInSideBar();
    });

    $("#start_free").click(function (e) {
        e.preventDefault();
        openSigInSideBar()
    });

    $('.user-auth .actions .btn-xs').click(function (e) {
        e.preventDefault();

        var id = '#' + $(this).attr('id') + '-form';
        var form = $(this).parents('form.local');
        var sibling = $(form).parent().find(id);

        $(form).removeClass('active');
        $(sibling).addClass('active');
    });

    $(window).on('resize', function (e) {
        if (getAbsolute()) {
            $(".social-links").addClass("absolute");
        } else {
            $(".social-links").removeClass("absolute");
        }
    });

    $("#search-toggle").click(function (e) {
        var parent = $("#navbar-search");
        if (!$(parent).hasClass('open')) {
            e.preventDefault();
            $(parent).addClass('open');
            $(this).addClass('toggled');
        } else {
            query = $(parent).find('input[type="search"]').val();
            if (query == "") {
                e.preventDefault();
                $(parent).removeClass("open");
            }
            $(this).removeClass('toggled');
        }
    });
}
function startTour(tour) {
    // Initialize the tour
    tour.init();
    // Start the tour
    tour.restart(true);
}



