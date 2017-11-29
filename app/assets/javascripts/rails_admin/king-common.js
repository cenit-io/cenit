$(document).ready(function () {

    /************************
     /*    LAYOUT
     /************************/

        // set minimum height for content wrapper
    $(window).bind("load resize scroll", function () {
        calculateContentMinHeight();
    });

    function calculateContentMinHeight() {
        $('#main-content-wrapper').css('min-height', $('#left-sidebar').height());
    }


    /************************
     /*    MAIN NAVIGATION
     /************************/
    $('.subdomain-menu .js-sub-menu-toggle').on('click', function (e) {

        e.preventDefault();

        var $li = $(this).parent('li'),
            $subdomain_side_bar_open = !$('#subdomain-sidebar').hasClass('minified');

        if (!$li.hasClass('active')) {
            $li.find(' > a .toggle-icon').removeClass('fa-angle-left').addClass('fa-angle-down');
            $li.addClass('active');
            $li.find(' > ul.sub-menu')
                .slideDown(300);
            if ($subdomain_side_bar_open) {
                $li.find(' > ul.sub-menu').addClass('open');
            }
            updateModelCountOneByOne(e);
        }
        else {
            $li.find(' > a .toggle-icon').removeClass('fa-angle-down').addClass('fa-angle-left');
            $li.removeClass('active');
            $li.find(' > ul.sub-menu')
                .slideUp(300);
            if ($subdomain_side_bar_open) {
                $li.find('> ul.sub-menu').removeClass('open');
            }
        }
    });

    $('.main-menu .js-sub-menu-toggle').on('click', function (e) {

        e.preventDefault();

        var $li = $(this).parent('li'),
            $left_side_bar_open = !$('#left-sidebar').hasClass('minified');

        if (!$li.hasClass('active')) {
            $li.find(' > a .toggle-icon').removeClass('fa-angle-left').addClass('fa-angle-down');
            $li.addClass('active');
            $li.find('> ul.sub-menu')
                .slideDown(300);
            if ($left_side_bar_open) {
                $li.find('> ul.sub-menu').addClass('open');
            }
        }
        else {
            $li.find(' > a .toggle-icon').removeClass('fa-angle-down').addClass('fa-angle-left');
            $li.removeClass('active');
            $li.find('> ul.sub-menu')
                .slideUp(300);
            if ($left_side_bar_open) {
                $li.find(' > ul.sub-menu').removeClass('open');
            }
        }
    });

    // checking for minified left sidebar
    checkMinified();

    $('.js-toggle-minified').on('click', function () {
        if (!$('.left-sidebar').hasClass('minified')) {
            $('.left-sidebar').addClass('minified');
            $('.content-wrapper').addClass('expanded');

        } else {
            $('.left-sidebar').removeClass('minified');
            $('.content-wrapper').removeClass('expanded');
        }

        checkMinified();
    });

    $('.js-related-toggle-minified').on('click', function () {
        if (!$('.related-sidebar').hasClass('minified')) {
            $('.related-sidebar').addClass('minified');
            $('aside').addClass('minified');

        } else {
            $('.related-sidebar').removeClass('minified');
            $('aside').removeClass('minified');
        }

        checkMinifiedRelated();
    });

    function checkMinified() {
        if (!$('.left-sidebar').hasClass('minified')) {
            setTimeout(function () {

                $('.left-sidebar .sub-menu.open')
                    .css('display', 'block')
                    .css('overflow', 'visible')
                    .siblings('.js-sub-menu-toggle').find('.toggle-icon').removeClass('fa-angle-left').addClass('fa-angle-down');
            }, 200);

            $('.main-menu > li > a > .text').animate({
                opacity: 1
            }, 1000);

        } else {
            $('.left-sidebar .sub-menu.open')
                .css('display', 'none')
                .css('overflow', 'hidden');

            $('.main-menu > li > a > .text').animate({
                opacity: 0
            }, 200);
        }
    }

    function checkMinifiedRelated() {
        if (!$('.related-sidebar').hasClass('minified')) {
            setTimeout(function () {

                $('.related-sidebar .sub-menu.open')
                    .css('display', 'block')
                    .css('overflow', 'visible')
                    .siblings('.js-sub-menu-toggle').find('.toggle-icon').removeClass('fa-angle-left').addClass('fa-angle-down');
            }, 200);

            $('.subdomain-menu > li > a > .text').animate({
                opacity: 1
            }, 1000);

        } else {
            $('.related-sidebar .sub-menu.open')
                .css('display', 'none')
                .css('overflow', 'hidden');

            $('.subdomain-menu > li > a > .text').animate({
                opacity: 0
            }, 200);
        }
    }

    $('.toggle-sidebar-collapse').on('click', function () {
        if ($(window).width() < 992) {
            // use float sidebar
            if (!$('.left-sidebar').hasClass('sidebar-float-active')) {
                $('.left-sidebar').addClass('sidebar-float-active');
            } else {
                $('.left-sidebar').removeClass('sidebar-float-active');
            }
        } else {
            // use collapsed sidebar
            if (!$('.left-sidebar').hasClass('sidebar-hide-left')) {
                $('.left-sidebar').addClass('sidebar-hide-left');
                $('.content-wrapper').addClass('expanded-full');
            } else {
                $('.left-sidebar').removeClass('sidebar-hide-left');
                $('.content-wrapper').removeClass('expanded-full');
            }
        }
    });

    $(window).bind("load resize", determineSidebar);

    function determineSidebar() {

        if ($(window).width() < 992) {
            $('body').addClass('sidebar-float');

        } else {
            $('body').removeClass('sidebar-float');
        }
    }

    // main responsive nav toggle
    $('.main-nav-toggle').clickToggle(
        function () {
            $('.left-sidebar').slideDown(300)
        },
        function () {
            $('.left-sidebar').slideUp(300);
        }
    );

    // slimscroll left navigation
    if ($('body.sidebar-fixed').length > 0) {
        $('body.sidebar-fixed .sidebar-scroll').slimScroll({
            height: '100%',
            wheelStep: 5,
        });
    }

    // widget toggle expand
    var affectedElement = $('.widget-content');

    $('.widget .btn-toggle-expand').clickToggle(
        function (e) {
            e.preventDefault();

            // if has scroll
            if ($(this).parents('.widget').find('.slimScrollDiv').length > 0) {
                affectedElement = $('.slimScrollDiv');
            }

            $(this).parents('.widget').find(affectedElement).slideUp(300);
            $(this).find('i.fa-chevron-up').toggleClass('fa-chevron-down');
        },
        function (e) {
            e.preventDefault();

            // if has scroll
            if ($(this).parents('.widget').find('.slimScrollDiv').length > 0) {
                affectedElement = $('.slimScrollDiv');
            }

            $(this).parents('.widget').find(affectedElement).slideDown(300);
            $(this).find('i.fa-chevron-up').toggleClass('fa-chevron-down');
        }
    );
    $('.widget .btn-toggle-expand.closed').trigger('click');

    // widget focus
    $('.widget .btn-focus').clickToggle(
        function (e) {
            e.preventDefault();
            $(this).find('i.fa-eye').toggleClass('fa-eye-slash');
            $(this).parents('.widget').find('.btn-remove').addClass('link-disabled');
            $(this).parents('.widget').addClass('widget-focus-enabled');
            $('body').addClass('focus-mode');
            $('<div id="focus-overlay"></div>').hide().appendTo('body').fadeIn(300);

        },
        function (e) {
            e.preventDefault();
            $theWidget = $(this).parents('.widget');

            $(this).find('i.fa-eye').toggleClass('fa-eye-slash');
            $theWidget.find('.btn-remove').removeClass('link-disabled');
            $('body').removeClass('focus-mode');
            $('body').find('#focus-overlay').fadeOut(function () {
                $(this).remove();
                $theWidget.removeClass('widget-focus-enabled');
            });
        }
    );

    /************************
     /*    BOOTSTRAP TOOLTIP
     /************************/

    $('body').tooltip({
        selector: "[data-toggle=tooltip]",
        container: "body"
    });


    /************************
     /*    BOOTSTRAP ALERT
     /************************/

    $('.alert .close').click(function (e) {
        e.preventDefault();
        $(this).parents('.alert').fadeOut(300);
    });
});

// toggle function
$.fn.clickToggle = function (f1, f2) {
    return this.each(function () {
        var clicked = false;
        $(this).bind('click', function () {
            if (clicked) {
                clicked = false;
                return f2.apply(this, arguments);
            }

            clicked = true;
            return f1.apply(this, arguments);
        });
    });

}