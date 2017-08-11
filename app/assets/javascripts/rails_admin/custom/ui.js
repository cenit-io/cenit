// require rails_admin/d3
// require rails_admin/highcharts
//= require rails_admin/utils
//= require rails_admin/toggle-origin.js
//= require rails_admin/bootstrap-tour.min
//= require rails_admin/triggers-box
//= require rails_admin/test-flow-transformation
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
});

$(function () {
    if ($(window).width() > 767) {
        $("#wrapper").addClass('toggled');
        $("#sidebar-toggle").addClass('toggled');
    }

    $("#sidebar-toggle").click(function (e) {
        e.preventDefault();
        $("#wrapper").toggleClass("toggled");
        $(this).toggleClass("toggled");
        var $conten_wraper = $("#content-wrapper");
        if ($("#sidebar-wrapper").css('width') == "55px") {

        } else {
            if ($("#wrapper").hasClass("toggled")) {
                $conten_wraper.css('width', 'calc(100% - 250px)');
            } else {
                $conten_wraper.css('width', 'calc(100% - 55px)');
            }

        }
    });

    $("#subdomain-toggle").click(function (e) {
        e.preventDefault();
        $("#subdomain-panel").toggleClass("collapsed");
        $(this).toggleClass("toggled");
    });

    $('#main-accordion').find('.panel-heading a.panel-title').click(function () {
        var parent = $(this).parent().parent();
        $(parent).toggleClass('active');
        if ($(parent).hasClass('active'))
            $(parent).siblings().each(function () {
                $(this).removeClass('active');
            });
    });

    $("#nav-drawer-toggle").click(function (e) {
        e.preventDefault();
        $("#nav-drawer").toggleClass('open');
        $(this).toggleClass("toggled");

        $("#sign-drawer").removeClass('open');
    });

    $("#sign-in-link").click(function (e) {
        e.preventDefault();
        $("#sign-drawer").toggleClass('open');
        // $(this).toggleClass("toggled");

        $("#nav-drawer").removeClass('open');
        $("#nav-drawer-toggle").removeClass("toggled");
    });

    $('.user-auth .actions .btn-xs').click(function (e) {
        e.preventDefault();

        var id = '#' + $(this).attr('id') + '-form';
        var form = $(this).parents('form.local');
        var sibling = $(form).parent().find(id);

        $(form).removeClass('active');
        $(sibling).addClass('active');
    });

    function getAbsolute() {
        var outer = $("#nav-drawer").height();
        var inner = $("#nav-links").height() + $("#social-links").height();

        return outer > inner;
    }

    $(window).on('resize', function (e) {
        if (getAbsolute()) {
            $(".social-links").addClass("absolute");
        } else {
            $(".social-links").removeClass("absolute");
        }
    });
    if (getAbsolute()) {
        $(".social-links").addClass("absolute");
    }

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

    registerEvents();
});

function initializeTour() {
    var toggle_collapse = function (id) {
            $('.panel-collapse', id).first().collapse('toggle');
            $(id).toggleClass('active');
        },
        tour = new Tour({
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
                    placement: "right",
                    onShow: function () {
                        that = this.element;
                        toggle_collapse(that);
                    },
                    onHide: function () {
                        that = this.element;
                        toggle_collapse(that);
                    }
                },
                {
                    title: "Define data",
                    content: "Create your schemas and data types",
                    element: "#main-definitions",
                    placement: "right",
                    onShow: function () {
                        that = this.element;
                        toggle_collapse(that);
                    },
                    onHide: function () {
                        that = this.element;
                        toggle_collapse(that);
                    }
                },
                {
                    title: "Store data",
                    content: "Store your objects",
                    element: "#main-json_data_type",
                    placement: "right",
                    onShow: function () {
                        that = this.element;
                        toggle_collapse(that);
                    },
                    onHide: function () {
                        that = this.element;
                        toggle_collapse(that);
                    }
                },
                {
                    title: "Setup your endpoints",
                    content: "Register connections and webhooks",
                    element: "#main-connectors",
                    placement: "right",
                    onShow: function () {
                        that = this.element;
                        toggle_collapse(that);
                    },
                    onHide: function () {
                        that = this.element;
                        toggle_collapse(that);
                    }
                },
                {
                    title: "Transform and dispatch",
                    content: "Send your data away or pull it from a remote endpoint or simply translate it from one data type to another",
                    element: "#main-transformations",
                    placement: "right",
                    onShow: function () {
                        that = this.element;
                        toggle_collapse(that);
                    },
                    onHide: function () {
                        that = this.element;
                        toggle_collapse(that);
                    }

                },
                {
                    title: "Safety first",
                    content: "Control who may access your stuff, and define how you access other's",
                    element: "#main-security",
                    placement: "right",
                    onShow: function () {
                        that = this.element;
                        toggle_collapse(that);
                    },
                    onHide: function () {
                        that = this.element;
                        toggle_collapse(that);
                    }
                },
                {
                    title: "Monitoring",
                    content: "Consult the status of every action",
                    element: "#main-monitors",
                    placement: "right",
                    onShow: function () {
                        that = this.element;
                        toggle_collapse(that);
                    },
                    onHide: function () {
                        that = this.element;
                        toggle_collapse(that);
                    }
                },
                // TODO: Where to go on this step
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
                },
                {
                    title: "REST API",
                    content: "Get help to use resources throw REST API",
                    element: "#rest-api",
                    placement: "left",
                    onShow: function () {
                        $('#nav-drawer').removeClass('open');
                    },
                    onHide: function () {
                        $('#nav-drawer').addClass('open');
                    }
                }
            ]
        });
    // Initialize the tour
    tour.init();

    // Start the tour
    tour.restart(true);
};
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
    tenants = tenants_list
    var i;
    for (i = 0; i < tenants.length; i++) {
        tenants[i] = JSON.parse(tenants[i]);
    }
}

var render_graphic = function ($form, selector) {
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
        initializeTour();
    });

    $('a#contact_us').click(function (e) {
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
        if (($target.parents('#subdomain-toggle').length == 0) && ($target.parents('#subdomain-panel').length == 0)) {
            $('#subdomain-panel').addClass('collapsed');
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
}

