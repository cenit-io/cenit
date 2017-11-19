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

        $li = $(this).parent('li');
        if (!$li.hasClass('active')) {
            $li.find(' > a .toggle-icon').removeClass('fa-angle-left').addClass('fa-angle-down');
            $li.addClass('active');
            $li.find('ul.sub-menu')
                .slideDown(300);
        }
        else {
            $li.find(' > a .toggle-icon').removeClass('fa-angle-down').addClass('fa-angle-left');
            $li.removeClass('active');
            $li.find('ul.sub-menu')
                .slideUp(300);
        }
    });

    $('.main-menu .js-sub-menu-toggle').on('click', function (e) {

        e.preventDefault();

        $li = $(this).parent('li');
        if (!$li.hasClass('active')) {
            $li.find(' > a .toggle-icon').removeClass('fa-angle-left').addClass('fa-angle-down');
            $li.addClass('active');
            $li.find('ul.sub-menu')
                .slideDown(300);
        }
        else {
            $li.find(' > a .toggle-icon').removeClass('fa-angle-down').addClass('fa-angle-left');
            $li.removeClass('active');
            $li.find('ul.sub-menu')
                .slideUp(300);
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


    //*******************************************
    /*	LIVE SEARCH
     /********************************************/

    $mainContentCopy = $('.main-content').clone();
    $('.searchbox input[type="search"]').keydown(function (e) {
        var $this = $(this);

        setTimeout(function () {
            var query = $this.val();

            if (query.length > 2) {
                var regex = new RegExp(query, "i");
                var filteredWidget = [];

                $('.widget-header h3').each(function (index, el) {
                    var matches = $(this).text().match(regex);

                    if (matches != "" && matches != null) {
                        filteredWidget.push($(this).parents('.widget'));
                    }
                });

                if (filteredWidget.length > 0) {
                    $('.main-content .widget').hide();
                    $.each(filteredWidget, function (key, widget) {
                        widget.show();
                    });
                } else {
                    console.log('widget not found');
                }
            } else {
                $('.main-content .widget').show();
            }
        }, 0);
    });

    // widget remove
    $('.widget .btn-remove').click(function (e) {

        e.preventDefault();
        $(this).parents('.widget').fadeOut(300, function () {
            $(this).remove();
        });
    });

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


    /************************
     /*    BOOTSTRAP POPOVER
     /************************/

    $('.btn-help').popover({
        container: 'body',
        placement: 'top',
        html: true,
        trigger: 'hover',
        title: '<i class="fa fa-book"></i> Quick Help',
        content: "Help summary goes here. Options can be passed via data attributes <code>data-</code> or JavaScript. You can change the popover trigger to 'click' instead of 'hover'."
    });

    $('.demo-popover1 #popover-title').popover({
        html: true,
        title: '<i class="fa fa-cogs"></i> Popover Title',
        content: 'This popover has title and support HTML content. Quickly implement process-centric networks rather than compelling potentialities. Objectively reinvent competitive technologies after high standards in process improvements. Phosfluorescently cultivate 24/365.'
    });

    $('.demo-popover1 #popover-hover').popover({
        html: true,
        title: '<i class="fa fa-cogs"></i> Popover Title',
        trigger: 'hover',
        content: 'Activate the popover on hover. Objectively enable optimal opportunities without market positioning expertise. Assertively optimize multidisciplinary benefits rather than holistic experiences. Credibly underwhelm real-time paradigms with.'
    });

    $('.demo-popover2 .btn').popover();


    /*****************************
     /*    WIDGET WITH AJAX ENABLE
     /*****************************/

    $('.widget-header-toolbar .btn-ajax').click(function (e) {
        e.preventDefault();
        $theButton = $(this);

        $.ajax({
            url: 'php/widget-ajax.php',
            type: 'POST',
            dataType: 'json',
            cache: false,
            beforeSend: function () {
                $theButton.prop('disabled', true);
                $theButton.find('i').removeClass().addClass('fa fa-spinner fa-spin');
                $theButton.find('span').text('Loading...');
            },
            success: function (data, textStatus, XMLHttpRequest) {

                setTimeout(function () {
                    getResponseAction($theButton, data['msg'])
                }, 1000);
                /* setTimeout is used for demo purpose only */

            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                console.log("AJAX ERROR: \n" + errorThrown);
            }
        });
    });

    function getResponseAction(theButton, msg) {

        $('.widget-ajax .alert').removeClass('alert-info').addClass('alert-success')
            .find('span').text(msg);

        $('.widget-ajax .alert').find('i').removeClass().addClass('fa fa-check-circle');

        theButton.prop('disabled', false);
        theButton.find('i').removeClass().addClass('fa fa-floppy-o');
        theButton.find('span').text('Update');
    }


    //*******************************************
    /*	WIDGET QUICK NOTE
     /********************************************/

    if ($('.quick-note-create').length > 0) {
        $('.quick-note-create textarea, .quick-note-create input').focusin(function () {
            $(this).attr('rows', 7);
            $('.quick-note-create').find('.widget-footer').show();
        });

        $('.quick-note-create').focusout(function () {
            $(this).find('textarea').attr('rows', 1);
            $(this).find('.widget-footer').hide();
        });
    }

    if ($('.quick-note-saved').length > 0) {
        $('.quick-note-saved').click(function () {
            $('#quick-note-modal').modal();
        });
    }

    if ($('.quick-note-edit').length > 0) {
        $('.quick-note-edit .btn-save').click(function () {
            $('#quick-note-modal').modal('hide');
        });
    }


    //*******************************************
    /*	WIDGET SLIM SCROLL
     /********************************************/

    if ($('.widget-scrolling').length > 0) {
        $('.widget-scrolling .widget-content').slimScroll({
            height: '410px',
            wheelStep: 5,
        });
    }


    //*******************************************
    /*	WIDGET WITH AJAX STATE
     /********************************************/

    if ($('#btn-ajax-state').length > 0) {
        $('#btn-ajax-state').click(function () {
            $statusPlaceholder = $(this).parents('.widget').find('.process-status');
            ajaxCallToDo($statusPlaceholder);
        });
    }


    /**************************************
     /*    MULTISELECT/SINGLESELECT DROPDOWN
     /**************************************/

    if ($('.widget-header .multiselect').length > 0) {

        $('.widget-header .multiselect').multiselect({
            dropRight: true,
            buttonClass: 'btn btn-warning btn-sm'
        });
    }


    //*******************************************
    /*	DASHBOARD REMINDER
     /********************************************/

    if ($('.today-reminder').length > 0) {
        var count = 0;
        var timer;
        var ringSound = new Audio();

        if (navigator.userAgent.match("Firefox/")) {
            ringSound.src = "assets/audio/bell-ringing.ogg";
        } else {
            ringSound.src = "assets/audio/bell-ringing.mp3";
        }

        function ringIt() {
            if (count < 3) { // adjust it with the css ring animation at .today-reminder

                // sound setting saved on localStorage as 0 or 1, by default sound on (null value on localStorage)
                $globalVolume = localStorage.getItem('global-volume');

                if (($globalVolume == null || $globalVolume == '1' )) {
                    ringSound.play();
                }

                timer = setTimeout(ringIt, 8000); // adjust it with the css ring animation at .today-reminder
                count++;
            }
        }

        ringIt();
    }


    //*******************************************
    /*	SWITCH INIT
     /********************************************/

    if ($('.bs-switch').length > 0) {
        $('.bs-switch').bootstrapSwitch();
    }


    //*******************************************
    /*	BOOTSTRAP TOUR
     /********************************************/

    var kingTour = new Tour({
        basePath: "edit/basepath/see/documentation/", // please see documentation for this setting
        steps: [
            {
                element: "#tour-searchbox",
                title: "Bootstrap Tour",
                content: "<p>Hello there, this tour can <strong>guide new user</strong> or show new feature/update on your website. " +
                "Oh and why don't you try search <em>'sales'</em> here to see Widget Live Search on action.</p>" +
                "<p><em>To navigate the site please follow the tour first or click \"End tour\".</em></p>",
                placement: "bottom"
            },
            {
                element: "#sales-stat-tab",
                title: "Dynamic Content",
                content: "You can select statistic view based on predefined period here."
            },
            {
                element: "#tour-focus",
                title: "Focus Mode",
                content: "Focus your attention and hide all irrelevant contents.",
                placement: "left"
            },
            {
                element: ".del-switcher-toggle",
                title: "Color Skins",
                content: "Open the hidden panel here by clicking this icon to apply built-in skins.",
                placement: "left",
                backdrop: true
            },
            {
                element: "#start-tour",
                title: "Start/Restart Tour",
                content: "Click this link later if you need to <strong>restart the tour</strong>.",
                placement: "bottom",
                backdrop: true
            }
        ],
        template: "<div class='popover tour'> " +
        "<div class='arrow'></div> " +
        "<h3 class='popover-title'></h3>" +
        "<div class='popover-content'></div>" +
        "<div class='popover-navigation'>" +
        "<button class='btn btn-default' data-role='prev'>« Prev</button>" +
        "<button class='btn btn-primary' data-role='next'>Next »</button>" +
        "<button class='btn btn-default' data-role='end'>End tour</button>" +
        "</div>" +
        "</div>",
        onEnd: function (tour) {
            $('#start-tour').prop('disabled', false);
        }
    });


    /************************
     /*    TOP BAR
     /************************/

    if ($('.top-general-alert').length > 0) {

        if (localStorage.getItem('general-alert') == null) {
            $('.top-general-alert').delay(800).slideDown('medium');
            $('.top-general-alert .close').click(function () {
                $(this).parent().slideUp('fast');
                localStorage.setItem('general-alert', 'closed');
            });
        }
    }

    kingTour.init();

    $('#start-tour').click(function () {
        if (kingTour.ended()) {
            kingTour.restart();
        } else {
            kingTour.start();
        }

        $(this).prop('disabled', true);
    });

    $btnGlobalvol = $('.btn-global-volume');
    $theIcon = $btnGlobalvol.find('i');

    // check global volume setting for each loaded page
    checkGlobalVolume($theIcon, localStorage.getItem('global-volume'));

    $btnGlobalvol.click(function () {
            var currentVolSetting = localStorage.getItem('global-volume');
            // default volume: 1 (on)
            if (currentVolSetting == null || currentVolSetting == "1") {
                localStorage.setItem('global-volume', 0);
            } else {
                localStorage.setItem('global-volume', 1);
            }

            checkGlobalVolume($theIcon, localStorage.getItem('global-volume'));
        }
    );

    function checkGlobalVolume(iconElement, vSetting) {
        if (vSetting == null || vSetting == "1") {
            iconElement.removeClass('fa-volume-off').addClass('fa-volume-up');
        } else {
            iconElement.removeClass('fa-volume-up').addClass('fa-volume-off');
        }
    }


    //*******************************************
    /*	SELECT2
     /********************************************/

    if ($('.select2').length > 0) {
        $('.select2').select2();
    }

    if ($('.select2-multiple').length > 0) {
        $('.select2-multiple').select2();
    }


    //*******************************************
    /*	DRAG & DROP TO-DO LIST
     /********************************************/

    if ($('.todo-list').length > 0) {
        $('#dragdrop-todo').sortable({
            revert: true,
            placeholder: "ui-state-highlight",
            handle: '.handle',
            update: function () {
                $status = $(this).parents('.widget').find('.process-status');
                ajaxCallToDo($status);
            }
        });

        $('.todo-list input').change(function () {
            if ($(this).prop('checked')) {
                $(this).parents('li').addClass('completed');
            } else {
                $(this).parents('li').removeClass('completed');
            }

            $status = $(this).parents('.widget').find('.process-status');
            ajaxCallToDo($status);
        });

        function ajaxCallToDo($status) {
            $.ajax({
                url: 'php/widget-ajax.php',
                type: 'POST',
                dataType: 'json',
                cache: false,
                beforeSend: function () {
                    $status.find('.loading').fadeIn(300);
                },
                success: function (data, textStatus, XMLHttpRequest) {

                    setTimeout(function () {
                        $status.find('span').hide();
                        $status.find('.saved').fadeIn(300);
                        console.log("AJAX SUCCESS");
                    }, 1000);

                    setTimeout(function () {
                        $status.find('.saved').fadeOut(300);
                    }, 2000);
                    /* all setTimeout is used for demo purpose only */

                },
                error: function (XMLHttpRequest, textStatus, errorThrown) {
                    $status.find('span').hide();
                    $status.find('.failed').addClass('active');
                    console.log("AJAX ERROR: \n" + errorThrown);
                }
            });
        }
    }

    function ajaxCallToDo($status) {
        $.ajax({
            url: 'php/widget-ajax.php',
            type: 'POST',
            dataType: 'json',
            cache: false,
            beforeSend: function () {
                $status.find('.loading').fadeIn(300);
            },
            success: function (data, textStatus, XMLHttpRequest) {

                setTimeout(function () {
                    $status.find('span').hide();
                    $status.find('.saved').fadeIn(300);
                    console.log("AJAX SUCCESS");
                }, 1000);

                setTimeout(function () {
                    $status.find('.saved').fadeOut(300);
                }, 2000);
                /* all setTimeout is used for demo purpose only */

            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                $status.find('span').hide();
                $status.find('.failed').addClass('active');
                console.log("AJAX ERROR: \n" + errorThrown);
            }
        });
    }


    //*******************************************
    /*	TEXTAREA FOR CHAT
     /********************************************/

    // enabling shift enter for new line
    $(".textarea-chat").keydown(function (e) {
        if (e.keyCode == 13 && !e.shiftKey) {
            e.preventDefault();
            console.log('send message');
            $(this).val('');
        }
    });


    //*******************************************
    /*	DATA COMPLETENESS METER
     /********************************************/

    if ($('.completeness-meter').length > 0) {
        var cPbar = $('.completeness-progress');

        if ($('.progress-bar').length > 0) {
            cPbar.progressbar({
                display_text: 'fill',
                update: function (current_percentage) {
                    $('.completeness-percentage').text(current_percentage + '%');

                    if (current_percentage == 100) {
                        $('.complete-info').addClass('text-success').html('<i class="ion ion-checkmark-circled"></i> Hooray, it\'s done!');
                        cPbar.removeClass('progress-bar-info').addClass('progress-bar-success');
                        $('.completeness-meter .editable').editable('disable');
                    }
                }
            });
        }

        $.fn.editable.defaults.mode = 'inline';

        $('#complete-phone-number').on('shown', function (e, editable) {
            editable.input.$input.mask('(999) 999-9999');
        }).on('hidden', function (e, reason) {
            if (reason == 'save') {
                $(this).parent().prepend('Phone: ');
                updateProgressBar(cPbar, 10);
            }
        });
        $('#complete-sex').on('hidden', function (e, reason) {
            if (reason == 'save') {
                $(this).parent().prepend('Sex: ');
                updateProgressBar(cPbar, 10);
            }
        });
        $('#complete-birthdate').on('hidden', function (e, reason) {
            if (reason == 'save') {
                $(this).parent().prepend('Birthdate: ');
                updateProgressBar(cPbar, 10);
            }
        });
        $('#complete-nickname').on('shown', function (e, editable) {
            editable.input.$input.val('');
        }).on('hidden', function (e, reason) {
            if (reason == 'save') {
                $(this).parent().prepend('Nickname: ');
                updateProgressBar(cPbar, 10);
            }
        });

        $('.completeness-meter #complete-phone-number').editable();
        $('#complete-sex').editable({
            source: [
                {value: 1, text: 'Male'},
                {value: 2, text: 'Female'}
            ]
        });
        $('#complete-birthdate').editable();
        $('#complete-nickname').editable();
    }

    function updateProgressBar(pbar, valueAdded) {
        pbar.attr('data-transitiongoal', parseInt(pbar.attr('data-transitiongoal')) + valueAdded).progressbar();
    }

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