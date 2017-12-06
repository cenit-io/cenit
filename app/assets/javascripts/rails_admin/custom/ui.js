//= require 'rails_admin/clipboard.min'
//= require 'rails_admin/disabled-event'
//= require 'horsey'
//= require 'rails_admin/owl.carousel'
//= require rails_admin/utils
//= require rails_admin/toggle-buttons.js
//= require rails_admin/triggers-box
//= require rails_admin/highlight_js/highlight.pack.js
//= require rails_admin/handlers
//= require rails_admin/highcharts
//= require rails_admin/chartkick
//= require lodash.min
//= require rails_admin/select2.full.min

$(document).on('rails_admin.dom_ready', function () {
    registerEvents();
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
    }),
    slideshow = {
        initialize: function () {
            var $slideshow = $(".slideshow"),
                $slides = $slideshow.find(".slide"),
                $btnPrev = $slideshow.find(".btn-nav.prev"),
                $btnNext = $slideshow.find(".btn-nav.next");

            var index = 0;
            var interval = setInterval(function () {
                index++;
                if (index >= $slides.length) {
                    index = 0;
                }
                updateSlides(index);
            }, 4500);

            $btnPrev.click(function () {
                clearInterval(interval);
                interval = null;
                index--;
                if (index < 0) {
                    index = $slides.length - 1;
                }
                updateSlides(index);
            });

            $btnNext.click(function () {
                clearInterval(interval);
                interval = null;
                index++;
                if (index >= $slides.length) {
                    index = 0;
                }
                updateSlides(index);
            });

            $slideshow.hover(function () {
                $btnPrev.addClass("active");
                $btnNext.addClass("active");
            }, function () {
                $btnPrev.removeClass("active");
                $btnNext.removeClass("active");
            });


            function updateSlides(index) {
                $slides.removeClass("active");
                $slides.eq(index).addClass("active");
            }
        }
    }
// Functions
function initHomePage() {

    $(".owl-carousel").owlCarousel({items: 3, autoPlay: true, pagination: false});

    var $navDots = $("#hero nav a")
    var $next = $(".slide-nav.next");
    var $prev = $(".slide-nav.prev");
    var $slides = $("#hero .slides .slide");
    var actualIndex = 0;
    var swiping = false;
    var interval;

    $navDots.click(function (e) {
        e.preventDefault();
        if (swiping) {
            return;
        }
        swiping = true;

        actualIndex = $navDots.index(this);
        updateSlides(actualIndex);
    });

    $next.click(function (e) {
        e.preventDefault();
        if (swiping) {
            return;
        }
        swiping = true;

        clearInterval(interval);
        interval = null;

        actualIndex++;
        if (actualIndex >= $slides.length) {
            actualIndex = 0;
        }

        updateSlides(actualIndex);
    });

    $prev.click(function (e) {
        e.preventDefault();
        if (swiping) {
            return;
        }
        swiping = true;

        clearInterval(interval);
        interval = null;

        actualIndex--;
        if (actualIndex < 0) {
            actualIndex = $slides.length - 1;
        }

        updateSlides(actualIndex);
    });

    function updateSlides(index) {
        // update nav dots
        $navDots.removeClass("active");
        $navDots.eq(index).addClass("active");

        // update slides
        var $activeSlide = $("#hero .slide.active");
        var $nextSlide = $slides.eq(index);

        $activeSlide.fadeOut();
        $nextSlide.addClass("next").fadeIn();

        setTimeout(function () {
            $slides.removeClass("next").removeClass("active");
            $nextSlide.addClass("active");
            $activeSlide.removeAttr('style');
            swiping = false;
        }, 1000);
    }
    // Uncomment this for automatic slide changing
    /*    interval = setInterval(function () {
            if (swiping) {
                return;
            }
            swiping = true;

            actualIndex++;
            if (actualIndex >= $slides.length) {
                actualIndex = 0;
            }

            updateSlides(actualIndex);
        }, 5000);
    */
}
function scroll_to(event) {
    event.preventDefault();
    var anchor = $(event.currentTarget).attr('data-link');
    if (anchor == 'top') {
        $("html, body").animate({scrollTop: 0}, 1000);
    } else {
        $("html, body").animate({scrollTop: (($('#' + anchor).offset().top - 78))}, 1000);
    }
}
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
    $(document).on('click', ".scroll", scroll_to);

    $(window).scroll(function () {
        var w = $(window), $go = $('#go-up');

        if (w.scrollTop() >= 1000) {
            if (!$go.hasClass('active')) {
                $go.addClass('active');
            }
        }
        else {
            if ($go.hasClass('active')) {
                $go.removeClass('active');
            }
        }
    });

    $(".go-sign-in").off().click(function (e) {
        e.preventDefault();
        openSigInSideBar();
    })

    var $main_accordion = $('#main-accordion');

    $('.expand_collapse').off().click(function (e) {
        $(e.target).parents('.wrapped').toggleClass('open');
    });

    $('.take-tour').off().click(function (e) {
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
    $('a#contact_us').off().click(function (e) {
        e.preventDefault();
        $('div#contact_us').modal({
            keyboard: true,
            backdrop: true,
            show: true
        })
    });
    $('.contact-modal').off().click(function (e) {
        e.preventDefault();
        $('div#contact_us').modal({
            keyboard: true,
            backdrop: true,
            show: true
        })
    });
    $(".soc-btn").off().on("click", function (ev) {
        $(this).addClass("selected");
        $(this).siblings().addClass("unused");

        var overlay = $('<div id="modal-overlay"></div>');
        overlay.appendTo(document.body);
    });
    $('#show_tenant_menu').off().on('click', function (e) {
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
    $('#search_tenant').off().on('keydown', function (e) {
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
    $("#view_graphic").off().click(function (e) {
        e.preventDefault();
        $('[name="enable_chart"]').val('true');
    });
    $("#sidebar-toggle").off().on('click', function (e) {
        e.preventDefault();

        var $content_wrapper = $("#content-wrapper"),
            $nav_icon = $(this).siblings().find('.nav-icon'),
            $wrapper = $("#wrapper"),
            $accordion = $('#main-accordion');

        $wrapper.toggleClass("toggled");
        $(this).toggleClass("toggled");

        if ($("#sidebar-wrapper").css('width') == "55px") {
            $nav_icon.removeClass('no-view');
            $content_wrapper.css('width', 'calc(100% - 250px)');

        } else {
            if ($wrapper.hasClass("toggled")) {
                $nav_icon.removeClass('no-view');
                $content_wrapper.css('width', 'calc(100% - 250px)');

            } else {
                $nav_icon.addClass('no-view');
                $content_wrapper.css('width', 'calc(100% - 55px)');

            }
            //$accordion.find('.panel-default').removeClass('active');
            //$accordion.find('.panel-collapse').removeClass('in')
        }
    });
    $("#subdomain-toggle").off().on('click', function (e) {
        e.stopPropagation();
        e.stopImmediatePropagation();
        $("#subdomain-panel").toggleClass("collapsed");
        var $subdomain = $(e.target).parents().find('#subdomain-toggle');
        $subdomain.toggleClass("toggled");
    });
    $main_accordion.find('.panel-heading a.panel-title').off().click(function () {
        var parent = $(this).parent().parent();
        $(parent).toggleClass('active');
        $main_accordion.find('.no-childrens a').removeClass('active');
        if ($(parent).hasClass('active'))
            $(parent).siblings().each(function () {
                $(this).removeClass('active');
            });
    });
    $main_accordion.find('li.no-childrens a').off().click(function () {
        var parent = $(this).parent().parent();
        $(parent).find('.no-childrens a').removeClass('active');
        $(parent).find('.panel-default').removeClass('active');
        if (!$(this).hasClass('active')) {
            $(this).addClass('active');
        }
    });
    $main_accordion.find('a[data-toggle="collapse"]').on('click', function () {
        var $conten_wraper = $("#content-wrapper"),
            $wrapper = $("#wrapper");
        if (!$wrapper.hasClass("toggled")) {
            $wrapper.addClass("toggled");
            $conten_wraper.css('width', 'calc(100% - 250px)');
        }
    });
    $("#nav-drawer-toggle").off().click(function (e) {
        e.preventDefault();
        $("#nav-drawer").toggleClass('open');
        $(this).toggleClass("toggled");

        $("#sign-drawer").removeClass('open');
    });
    $("#sign-in-link").off().click(function (e) {
        e.preventDefault();
        openSigInSideBar();
    });
    $("#start_free").off().click(function (e) {
        e.preventDefault();
        openSigInSideBar()
    });
    $('.user-auth .actions .btn-xs').off().click(function (e) {
        e.preventDefault();

        var id = '#' + $(this).attr('id') + '-form';
        var form = $(this).parents('form.local');
        var sibling = $(form).parent().find(id);

        $(form).removeClass('active');
        $(sibling).addClass('active');
    });
    $(window).off('resize').on('resize', function (e) {
        if (getAbsolute()) {
            $(".social-links").addClass("absolute");
        } else {
            $(".social-links").removeClass("absolute");
        }
    });
    $("#search-toggle").off().click(function (e) {
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
    $('#model-nav-xs').off().on('click', function (e) {
        var $secondary_nav = $('#secondary-navigation-xs');
        if ($secondary_nav.hasClass('in')) {
            $secondary_nav.removeClass('in');
        }
    });
    $('#secondary-nav-xs').off().on('click', function (e) {
        var $model_nav = $('#models-navigation-xs');
        if ($model_nav.hasClass('in')) {
            $model_nav.removeClass('in');
        }
    });
}
function startTour(tour) {
    // Initialize the tour
    tour.init();
    // Start the tour
    tour.restart(true);
}



