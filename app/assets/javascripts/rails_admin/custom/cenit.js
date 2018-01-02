var cenit = (function ($) {
    // Module scope variables
    var
    // Set constants

        configMap = {
            sample: 0,
        },

    // Vars

        graphics_handle,

    // widget toggle expand
        affectedElement = $('.widget-content'),

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
        };

    // Functions

    initHomePage = function () {

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
    },

        scroll_to = function (event) {
            event.preventDefault();
            var anchor = $(event.currentTarget).attr('data-link');
            if (anchor == 'top') {
                $("html, body").animate({scrollTop: 0}, 1000);
            } else {
                $("html, body").animate({scrollTop: (($('#' + anchor).offset().top - 78))}, 1000);
            }
        },

        openSigInSideBar = function () {
            $("#sign-drawer").toggleClass('open');
            // $(this).toggleClass("toggled");

            $("#nav-drawer").removeClass('open');
            $("#nav-drawer-toggle").removeClass("toggled")
        },

        getAbsolute = function () {
            var outer = $("#nav-drawer").height();
            var inner = $("#nav-links").height() + $("#social-links").height();

            return outer > inner;
        },

        openNavigator = function () {
            var $subdomain_panel;
            if ($('#main-dashboard').length == 0) {
                $subdomain_panel = $('#subdomain-panel');
                if ($subdomain_panel.hasClass('collapsed')) {
                    $("#subdomain-toggle").trigger('click');
                }
            }
        },

        toggle_collapse = function (id) {
            $('.panel-collapse', id).first().collapse('toggle');
            $(id).toggleClass('active');
        },

        filterTenants = function (text) {
            var i, t, results = [];
            for (i = 0; i < tenants.length; i++) {
                t = tenants[i];
                if (t['name'].match(text) != null) {
                    results.push(t);
                }
            }
            return results;
        },

        load_tenant_list = function (tenants_list) {
            tenants = tenants_list;
            var i;
            for (i = 0; i < tenants.length; i++) {
                tenants[i] = JSON.parse(tenants[i]);
            }
        },

        render_graphic = function ($form, selector) {
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
        },

        startTour = function (tour) {
            // Initialize the tour
            tour.init();
            // Start the tour
            tour.restart(true);
        },

        testing = function () {
            alert(5);
        },

        schedulerInit = function ($this) {
            var top_level = $this;

            function zp(num) {
                if (parseInt(num) > 9)
                    return num;
                return '0' + num;
            }

            var date_start_input = top_level.find('#start_date');
            var date_start = date_start_input.val();
            date_start_input.datetimepicker({format: "YYYY-MM-DD", allowInputToggle: true});
            date_start_input.val(date_start);

            var time_start_input = top_level.find('#start_time');
            var time_start = time_start_input.val();
            time_start_input.datetimepicker({format: "HH:mm", allowInputToggle: true});
            var t = time_start.split(':');
            time_start_input.val(zp(t[0]) + ':' + zp(t[1]));

            var date_end_input = top_level.find('#end_date');
            var date_end = date_end_input.val();
            date_end_input.datetimepicker({format: "YYYY-MM-DD", allowInputToggle: true});
            date_end_input.val(date_end);

            var freq_sel = top_level.find('#frequency');
            top_level.addClass('selected-' + freq_sel.val());

            top_level.find('.scheduler-opts a.btn').click(function (e) {
                e.preventDefault();
                $(this).toggleClass('btn-primary');
                $(this).toggleClass('btn-default');
            });

            top_level.parents('form').on('submit', function () {
                updateExpression();
            });

            freq_sel.change(function () {
                var current = $(this).val();

                for (var i = 0; i < 6; i++)
                    top_level.removeClass('selected-' + i);
                top_level.addClass('selected-' + current);
            });

            function ensureInRange(val, min, max) {
                if (!val)
                    return min;
                var cur = parseInt(val);
                if (cur < min)
                    return min;
                else if (cur > max)
                    return max;
                return cur;
            }

            var cyclic_num = $('#cyclic_num');
            var cyclic_unit = $('#cyclic_unit');

            function ensureMins() {
                var min = 1;
                var max = 1000;

                if (cyclic_unit.val() == 'm') {
                    min = 20;
                    max = 110;
                }

                var val = parseInt(cyclic_num.val());
                val = ensureInRange(val, min, max);
                cyclic_num.val(val)
            }

            cyclic_num.on('input', ensureMins);
            cyclic_unit.on('change', ensureMins);

            $('#days_sl').on('change', function () {
                $('#days_1').toggleClass('hidden');
                $('#days_2').toggleClass('hidden');
            });

            $('#start_sl').on('change', function () {
                $('#start_1').toggleClass('hidden');
                $('#start_2').toggleClass('hidden');
            });

            $('#end_sl').on('change', function () {
                $('#end_1').toggleClass('hidden');
                $('#end_2').toggleClass('hidden');
            });

            function updateExpression() {
                var res = {};

                switch ($('#start_sl').val()) {
                    case "1":
                        res["start_at"] = date_start_input.val();
                }

                switch ($('#end_sl').val()) {
                    case "1":
                        res['end_at'] = date_end_input.val();
                        break;
                    case "2":
                        res['max_repeat'] = parseInt($("max_repeat").val());
                        break;
                }

                var level = parseInt(freq_sel.val());

                if (level == 0) {
                    res["type"] = 'once';
                } else if (level == 1) {
                    res["type"] = 'cyclic';
                    res["cyclic_expression"] = $('#cyclic_num').val() + ($('#cyclic_unit').val());
                } else {
                    res["type"] = 'appointed';
                    var start_time = time_start_input.val();
                    res["hours"] = [parseInt(start_time.split(':')[0])];
                    res["minutes"] = [parseInt(start_time.split(':')[1])];

                    var dval = $("#days_sl").val();
                    if (dval == "1") {
                        res["weeks_days"] = _.filter(_.range(0, 7), function (e) {
                            return $("#week_day_" + e).hasClass("btn-primary");
                        });

                        res["weeks_month"] = _.filter(_.range(0, 4), function (e) {
                            return $("#weeks_monthly_at_" + e).hasClass("btn-primary");
                        });
                        res["last_week_in_month"] = $('#last_week_in_month').hasClass("btn-primary");
                    } else {
                        res["months_days"] = _.filter(_.range(0, 31), function (e) {
                            return $("#months_day_" + e).hasClass("btn-primary");
                        });
                        res["last_day_in_month"] = $('#last_day_in_month').hasClass("btn-primary");
                    }

                    res["months"] = _.filter(_.range(1, 13), function (e) {
                        return $("#month_" + e).hasClass("btn-primary");
                    });
                }
                $("#setup_scheduler_expression").val(JSON.stringify(res));
            }

            updateExpression();
        },

        algorithmInit = function () {
            var output_store = $('#setup_algorithm_store_output');
            var output_datatype_field = $('#setup_algorithm_output_datatype_id_field');
            var output_validate_field = $('#setup_algorithm_validate_output_field');

            var output_datatype = $('#setup_algorithm_output_datatype_id');
            var output_validate = $('#setup_algorithm_validate_output');

            var parameters_root = $('#setup_algorithm_parameters_attributes_field');

            if (!output_store)
                return;

            function updateView() {
                output_datatype_field.addClass('hidden');
                output_validate_field.addClass('hidden');

                var store = output_store.is(':checked');
                if (store) {
                    output_datatype_field.removeClass('hidden');

                    var dt = output_datatype.val();
                    if (dt) {
                        output_validate_field.removeClass('hidden');
                    } else {
                        output_validate.removeAttr('checked');
                    }
                } else {
                    output_datatype.val('');
                    output_datatype.children().removeAttr('selected');
                    output_datatype_field.find('input').val('');
                    output_validate.removeAttr('checked');
                }
            }

            output_store.on('change', updateView);
            output_datatype.on('change', updateView);
            updateView();

            function updateParameter(top) {
                var default_field = $(top).find('.default_field');
                var required_input = $(top).find('.required_field input[type=checkbox]');

                if (required_input.is(':checked')) {
                    default_field.addClass('hidden');
                    // default_field.find('textarea').attr('required', false);
                } else {
                    default_field.removeClass('hidden');
                    // default_field.find('textarea').attr('required', true);
                }

                default_field.find('.help-block').hide();
            }

            parameters_root.find('.tab-pane').each(function () {
                var root = this;
                updateParameter(root);
                $(root).find('.required_field input[type=checkbox]').on('change', function () {
                    updateParameter(root);
                })
            });
        },

        selectTagsInit = function () {
            $('.select-tag').select2({theme: "bootstrap", tags: true})
        },

        cenitOauthScopeInit = function () {
            $(document).on('click', '.remove_data_type_actions', function () {
                var field_class = $(this).data('field-class');
                var $context = $('.' + field_class + ' .cenit-oauth-scope');
                $(this).parents('.scope').remove();
                if ($context.find('tr.scope').length == 0) {
                    $context.find('thead').addClass('hide');
                    $context.find('tfoot').addClass('hide');
                }
            });
            $('.add_data_type_actions').on('click', function () {
                var field_class = $(this).data('field-class');
                var $context = $('.' + field_class);

                if ($('.model-tr [data-filteringselect="true"] option:selected', $context).val().length == 0) {
                    //alert('Need to select a Data Type');
                } else {

                    $('thead.hide', $context).removeClass('hide');
                    var $copied = $('.model-tr tr.scope', $context).clone();
                    $copied.appendTo(".cenit-oauth-scope");
                    $copied.find('.remove_data_type_actions').removeClass('hide');
                    $copied.find('td div.hide').removeClass('hide');
                    $copied.find('td div.add_actions').remove();
                    $copied.find('.select2-container').remove();
                    $copied.find('.select-tag-no-add').removeClass('.select2-hidden-accessible hide').select2({
                        theme: "bootstrap",
                        tags: true,
                        createTag: function (params) {
                            // Don't offset to create a tag if there is no @ symbol
                            if (params.term.indexOf('@') === -1) {
                                // Return null to disable tag creation
                                return null;
                            }

                            return {
                                id: params.term,
                                text: params.term
                            }
                        }
                    });
                    var data_type_id = $('[data-filteringselect="true"] option:selected', $copied).val();
                    var data_type_name = $('[data-filteringselect="true"]', $copied).text();

                    var href = $copied.find('.hidden_link').attr('href');
                    $copied.find('.hidden_link').text(data_type_name);
                    href = href.replace(/__ID__/, data_type_id);
                    $copied.find('.hidden_link').attr('href', href);

                    $copied.find('.filtering-select').remove();
                    $copied.find('[data-filteringselect="true"]').remove();

                    var name = $copied.find('select').attr('name');
                    name = name.replace(/__ID__/, data_type_id);
                    $copied.find('select').attr('name', name);

                    $copied.find('data-type-link').removeClass('hide');

                    $('.cenit-oauth-scope .new-select-tag', $context).addClass('select-tag').removeClass('new-select-tag');
                    $('.cenit-oauth-scope .select-tag', $context).select2({theme: "bootstrap", tags: true})
                    $('.model-tr [data-filteringselect="true"] option:selected', $context).val('');
                    $('.model-tr .ra-filtering-select-input', $context).val('');
                    $context.find('thead.hide').removeClass('hide');
                    $context.find('tfoot.hide').removeClass('hide');
                }
            })
        },

        graphicsInit = function () {
            $('select.input-sm', '.graphics-controls').on('change', function (e) {
                graphic_control_change(e);
            });
            $(document).off('click', '#show_graphics').on('click', '#show_graphics', function () {
                $('.g-container').toggleClass('closed');
                var isclosed = $('.g-container').hasClass('closed'), $show = $('#show_graphics span');

                if (isclosed) {
                    $show.html('Show Chart');
                }
                else {
                    $show.html('Hide Chart');
                }

            });
        },

        graphic_control_change = function (e) {
            if (graphics_handle) {
                clearTimeout(graphics_handle);
            }
            graphics_handle = setTimeout(function () {
                var $form = $('#graphics-form');
                $form.submit();
            }, 2000);
        },

        drawGraphics = function (options) {
            $('.new_g').html('<i class="fa fa-spinner fa-spin fa-3x fa-fw"></i><span class="sr-only">Loading...</span>')
            var execution_route = '/api/v2/setup/execution/',
                host = options.host,
                exec_id = options.exec_id,
                graphic_type = options.graphic_type,
                graphic_options = {chart: {zoomType: 'x', style: {overflow: 'visible'}}},
                element_id = options.element_id,
                request_interval = options.request_interval,
                graphic_data,
                render_graphic = function (graphic_type, graphic_data, graphic_options, element_id) {
                    switch (graphic_type) {
                        case 'line_chart':
                            new Chartkick.LineChart(element_id, graphic_data, graphic_options);
                            break;
                        case 'pie_chart':
                            new Chartkick.PieChart(element_id, graphic_data, graphic_options);
                            break;
                        case 'column_chart':
                            new Chartkick.ColumnChart(element_id, graphic_data, graphic_options);
                            break;
                        case 'bar_chart':
                            new Chartkick.BarChart(element_id, graphic_data, graphic_options);
                            break;
                        case 'area_chart':
                            new Chartkick.AreaChart(element_id, graphic_data, graphic_options);
                            break;
                        case 'scatter_chart':
                            new Chartkick.ScatterChart(element_id, graphic_data, graphic_options);
                            break;
                        case 'geo_chart':
                            new Chartkick.GeoChart(element_id, graphic_data, graphic_options);
                            break;
                        case 'timeline':
                            new Chartkick.Timeline(element_id, graphic_data, graphic_options);
                            break;
                        case 'variable_chart':
                            new Chartkick.Timeline(element_id, graphic_data, graphic_options);
                            break;
                        default:
                            new Chartkick.LineChart(element_id, graphic_data, graphic_options);
                            break;
                    }
                },
                retrieve_data = function (attachment_url) {
                    $.ajax({
                            type: "GET",
                            url: attachment_url
                        })
                        .done(function (data) {
                            graphic_data = data;
                            console.log(graphic_data);
                            $('.new_g').html('<div id="' + element_id + '"></div>');
                            render_graphic(graphic_type, graphic_data, graphic_options, element_id);
                            $('.g-controls').removeClass('hide');
                            $('#show_graphics').removeClass('hide');
                        });
                },
                encuest_api = function () {
                    $.ajax({
                            type: "GET",
                            url: host + execution_route + exec_id,
                            cache: false
                        })
                        .done(function (data) {
                            if (data.status == "failed") {
                                $('.new_g').html('');
                                console.log('An error happened while executing de chart data generating task')
                            } else {
                                if (data.status == "completed") {
                                    var data_url = data.attachment.url;
                                    retrieve_data(data_url);
                                }
                                else {
                                    setTimeout(encuest_api, request_interval);
                                }
                            }

                        });
                }
            encuest_api();
        },

        // Setup a toggle-boolean element
        setupToggleBoolean = function (e) {
            var value = e.attributes['data-value'].value,
                indicator = '&#x2012;',
                iclass = 'default',
                indicatorElement = $(e.previousElementSibling);
            if (value == 'true') {
                indicator = '&#x2713;';
                iclass = 'success';
            }
            else if (value == 'false') {
                indicator = '&#x2718;';
                iclass = 'danger';
            }
            indicatorElement.removeClass();
            indicatorElement.addClass('label label-' + iclass);
            indicatorElement.html(indicator);
            e.innerHTML = '<i class="fa fa-toggle-' + (value == 'true' ? 'on' : 'off') + '"></i>';
            e.title = value == 'true' ? 'Set to false' : 'Set to true';
        },

        // Setup an auto-complete element
        setupAutoComplete = function (el) {
            var $el = $(el);
            var source = $el.data("auto-complete-source");
            var anchor = $el.data("auto-complete-anchor");
            horsey(el, {
                source: [{list: source}],
                getText: 'text',
                getValue: 'value',
                anchor: anchor
            });
        },

        // Side Menu Bar Update Model Counts Functions
        updateModelCountOneByOneNoChild = function () {
            $cenit_submenu_children = $('#subdomain-menu > li[data-model]');
            requestModelCount();
        },

        updateModelCountOneByOne = function (e) {
            e.stopPropagation();
            $cenit_submenu_children = $(e.currentTarget).siblings().find('li[data-model]');
            requestModelCount();
        },

        requestModelCount = function () {
            var array_of_children = $cenit_submenu_children.toArray();
            if (array_of_children.length > 0) {
                var $this = $(array_of_children.shift()), model = $this.data('model');
                $cenit_submenu_children = $(array_of_children);
                if (model != undefined) {
                    getModelCountOneByOne($this, $this.data('model'), $this.data('origins'), $this.data('ext'));
                }
            }
        },

        getModelCountOneByOne = function ($element, model_name, origins, ext) {
            var model_route = '/api/v2',
                counts = {}, origin,
                host = window.location.origin,
                get_count = function (model_name, origin, counts) {
                    var update_counts = function ($element, counts) {
                            var keys = Object.keys(counts),
                                values = [],
                                title = "and that's all!",
                                key,
                                not_cero_keys_count = 0,
                                not_cero_keys = [],
                                $amount = $element.find('.nav-amount');

                            if (keys.length > 0) {
                                $amount.text('');
                                $amount.children().remove();
                                $amount.removeClass('active');
                                for (var i = 0; i < keys.length; i++) {
                                    key = keys[i];
                                    if (counts[key] != 0) {
                                        values[not_cero_keys_count] = counts[key];
                                        not_cero_keys[not_cero_keys_count] = key;
                                        not_cero_keys_count++;
                                    }
                                }
                                if (not_cero_keys.length == 1) {
                                    $amount.text(values[0]);
                                    $amount.attr('title', title);
                                    $amount.addClass('active');
                                }
                                if (not_cero_keys.length > 1) {
                                    $amount.addClass('active');
                                    $amount.text(values[0] + ' +');
                                    var title = '+';
                                    for (var j = 1; j < not_cero_keys.length; j++) {
                                        if (values[j] != 0) {
                                            if (j === 1) {
                                                title += values[j] + ' ' + not_cero_keys[j];
                                            }
                                            else {
                                                if (j + 1 === not_cero_keys.length) {
                                                    title += ' and ' + values[j] + ' ' + not_cero_keys[j];
                                                } else {
                                                    title += ', ' + values[j] + ' ' + not_cero_keys[j];
                                                }
                                            }
                                        }
                                    }
                                    $amount.attr('title', title);
                                }
                            }
                            else {
                                $amount.text('');
                                $amount.children().remove();
                                $amount.removeClass('active');
                                $amount.append($('<i class="fa fa-spinner fa-pulse"></i>'));
                            }
                        },
                        request_origin_count = function (model_name, counts) {
                            if (cenit_model_origin_list.length > 0) {
                                origin = cenit_model_origin_list.shift();
                                get_count(model_name, origin, counts);
                            } else {
                                requestModelCount();
                            }
                        },
                        $amount = $element.find('.nav-amount');
                    var ajx_url = host + model_route + '/' + model_name + '?limit=1&only=id'
                    if (model_name === 'renderer') {
                        model_route = model_route + '/setup';
                        ajx_url = host + model_route + '/' + model_name + '?file_extension=' + ext;
                        origin = null;
                    }
                    if (origin) {
                        ajx_url = ajx_url + '&origin=' + origin;
                        $.ajax({
                                type: "GET",
                                url: ajx_url,
                                beforeSend: function () {
                                    update_counts($element, {});
                                }
                            })
                            .done(function (data) {
                                counts[origin] = data.count;
                                update_counts($element, counts);
                                request_origin_count(model_name, counts);
                            })
                            .fail(function () {
                                $amount.children().remove();
                                request_origin_count(model_name, counts);
                            });
                    }
                    else {
                        $.ajax({
                                type: "GET",
                                url: ajx_url,
                                beforeSend: function () {
                                    update_counts($element, {});
                                }
                            })
                            .done(function (data) {
                                counts['no_origins'] = data.count;
                                update_counts($element, counts);
                                requestModelCount();
                            })
                            .fail(function () {
                                $amount.children().remove();
                                requestModelCount();
                            });
                    }
                };

            origins = origins || ''
            if (origins.length > 0) {
                cenit_model_origin_list = origins.split(',');
                origin = cenit_model_origin_list.shift();
                get_count(model_name, origin, counts);
            } else {
                get_count(model_name, null, counts);
            }
        },

        // DashBoard Update Model Counts Functions

        updateDashboardCount = function (e) {
            if (e) {
                var tab_id = $(e.target).attr('href');
                $cenit_dashboard_models = $(tab_id).find('.model_count');
                $cenit_dashboard_max_model_count = -1;
            }
            else {
                $cenit_dashboard_models = $($('.tab-pane.active .monitor .model_count'));
                $cenit_dashboard_max_model_count = -1;

            }
            requestDashBoardModelCount();
        },

        requestDashBoardModelCount = function () {
            var array_of_models = $cenit_dashboard_models.toArray();
            if (array_of_models.length > 0) {
                var $this = $(array_of_models.shift());
                $cenit_dashboard_models = $(array_of_models);
                getModelCountForDashBoard($this, $this.data('model'), $this.data('origins'), $this.data('ext'));
            }
        },

        getModelCountForDashBoard = function ($element, model_name, origins, ext) {
            var model_route = '/api/v2',
                origin_list = [],
                counts = {},
                host = window.location.origin,
                get_count = function (model_name, origin, counts) {
                    var update_counts = function ($element, counts) {
                            var keys = Object.keys(counts),
                                values = [],
                                title = "",
                                key,
                                not_cero_keys_count = 0,
                                not_cero_keys = [],
                                $amount = $element;

                            if (keys.length > 0) {
                                $amount.text('0');
                                $amount.children().remove();
                                $amount.removeClass('active');
                                for (var i = 0; i < keys.length; i++) {
                                    key = keys[i];
                                    if (counts[key] != 0) {
                                        values[not_cero_keys_count] = counts[key];
                                        not_cero_keys[not_cero_keys_count] = key;
                                        not_cero_keys_count++;
                                    }
                                }
                                if (not_cero_keys.length == 1) {
                                    $amount.text(values[0]);
                                    $amount.attr('title', title);
                                    $amount.addClass('active');
                                }
                                if (not_cero_keys.length > 1) {
                                    $amount.addClass('active');
                                    $amount.text(values[0] + ' +');
                                    var title = '+';
                                    for (var j = 1; j < not_cero_keys.length; j++) {
                                        if (values[j] != 0) {
                                            if (j === 1) {
                                                title += values[j] + ' ' + not_cero_keys[j];
                                            }
                                            else {
                                                if (j + 1 === not_cero_keys.length) {
                                                    title += ' and ' + values[j] + ' ' + not_cero_keys[j];
                                                } else {
                                                    title += ', ' + values[j] + ' ' + not_cero_keys[j];
                                                }
                                            }
                                        }
                                    }
                                    $amount.attr('title', title);
                                }
                            }
                            else {
                                $amount.text('');
                                $amount.children().remove();
                                var $count = $amount.parent().parent().find('.model_count');
                                $count.text('');
                                $count.children().remove();
                                $count.append($('<i class="fa fa-spinner fa-pulse"></i>'));
                            }
                        },
                        update_max_count = function (count) {
                            if (count > $cenit_dashboard_max_model_count) {
                                $cenit_dashboard_max_model_count = count
                            }
                        },
                        request_dashboard_count = function () {
                            if ($cenit_dashboard_models.length > 0) {
                                requestDashBoardModelCount();
                            } else {
                                update_dashboard_model_percents();
                            }
                        };
                    if (origin) {
                        var ajx_url = host + model_route + '/' + model_name + '?limit=1&only=id&origin=' + origin
                        $.ajax({
                                type: "GET",
                                url: ajx_url,
                                beforeSend: function () {
                                    update_counts($element, {});
                                }
                            })
                            .done(function (data) {
                                counts[origin] = data.count;
                                update_max_count(data.count);
                                update_counts($element, counts);
                                request_dashboard_count();
                            })
                            .fail(function () {
                                counts['no_origins'] = 0;
                                update_counts($element, counts);
                                request_dashboard_count();
                            });
                    }
                    else {
                        $.ajax({
                                type: "GET",
                                url: host + model_route + '/' + model_name + '?limit=1&only=id',
                                beforeSend: function () {
                                    update_counts($element, {});
                                }
                            })
                            .done(function (data) {
                                counts['no_origins'] = data.count;
                                update_counts($element, counts);
                                update_max_count(data.count);
                                request_dashboard_count();
                            })
                            .fail(function () {
                                counts['no_origins'] = 0;
                                update_counts($element, counts);
                                request_dashboard_count();
                            });
                    }
                };
            origins = origins || '';
            counts = {}
            if (origins.length > 0) {
                origin_list = origins.split(',');
                // Only the first origin matters
                get_count(model_name, origin_list[0], counts);
            } else {
                get_count(model_name, null, counts);
            }
        },

        update_dashboard_model_percents = function () {
            var $model_count = $('.model_count'),
                percent_value,
                $this, text, indicator, anim,
                max = parseInt($cenit_dashboard_max_model_count),
                get_indicator = function (percent) {
                    if (percent < 0) {
                        return ''
                    } else {
                        if (percent < 34) {
                            return 'info'
                        } else {
                            if (percent < 67) {
                                return 'success'
                            } else {
                                if (percent < 84) {
                                    return 'warning'
                                } else {
                                    return 'danger'
                                }
                            }
                        }
                    }
                },
                percent = function (count, max) {
                    var percent;
                    if (count > 0) {
                        if (max <= 1) {
                            percent = count;
                        }
                        else {
                            percent = parseInt((Math.log(count + 1) * 100.0) / Math.log(max + 1))
                        }
                        return percent;
                    } else {
                        return -1
                    }
                };

            $model_count.each(function () {
                $this = $(this);
                text = $this.text();
                percent_value = percent(parseInt(text), max);
                indicator = get_indicator(percent_value);
                $this.html(text);
                $this.removeClass().addClass('model_count').addClass(indicator);

            });
        },

        // Layout and Sidebars functions

        initRelatedMenu = function () {
            if (window.innerWidth < 992) {
                $('.related-sidebar').addClass('minified');
                $('aside').addClass('minified');
            }
        },

        calculateContentMinHeight = function () {
            $('#main-content-wrapper').css('min-height', $('#left-sidebar').height());
        },

        checkMinified = function () {
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
        },

        checkMinifiedRelated = function () {
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
        },

        determineSidebar = function () {

            if ($(window).width() < 992) {
                $('body').addClass('sidebar-float');

            } else {
                $('body').removeClass('sidebar-float');
            }
        },
        update_active_nav_link = function () {
            var active_model,
                paths = window.location.pathname.split('/')
            if (paths.length > 1) {
                active_model = paths[1]
            }
            $('.subdomain-menu li').removeClass('active')
            $('.subdomain-menu a[href="/'+ active_model +'"]').parent().addClass('active')

        },

        registerEvents = function () {

            $('.dashboard a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
                updateDashboardCount(e);
            })

            $('#subdomain-related-menu a[data-toggle="collapse"]').off('click').on('click', function (e) {
                var $aside = $('#content-wrapper aside');
                if ($aside.hasClass('minified')) {
                    $aside.removeClass('minified');
                }

            });
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
            $('#toogle-submenu-header').off().click(function (e) {
                $('.collapsed-sm').toggleClass('open');
                $('#toogle-submenu-header').toggleClass('open');
            });

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
            // Layout and Sidebars events

            $(window).bind("load resize scroll", function () {
                calculateContentMinHeight();
            });
            $('.subdomain-menu .js-sub-menu-toggle').off().on('click', function (e) {

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

            $('.main-menu .js-sub-menu-toggle').off().on('click', function (e) {

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

            $('.js-toggle-minified').off().on('click', function () {
                if (!$('.left-sidebar').hasClass('minified')) {
                    $('.left-sidebar').addClass('minified');
                    $('.content-wrapper').addClass('expanded');

                } else {
                    $('.left-sidebar').removeClass('minified');
                    $('.content-wrapper').removeClass('expanded');
                }

                checkMinified();
            });


            $('.js-related-toggle-minified').off().on('click', function () {
                if (window.innerWidth > 992) {
                    if (!$('.related-sidebar').hasClass('minified')) {
                        $('.related-sidebar').addClass('minified');
                        $('aside').addClass('minified');

                    } else {
                        $('.related-sidebar').removeClass('minified');
                        $('aside').removeClass('minified');
                    }

                    checkMinifiedRelated();
                }
            });

            $('.toggle-sidebar-collapse').off().on('click', function () {
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

            $('.main-nav-toggle').clickToggle(
                function () {
                    $('.left-sidebar').slideDown(300)
                },
                function () {
                    $('.left-sidebar').slideUp(300);
                }
            );
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

            $('body').tooltip({
                selector: "[data-toggle=tooltip]",
                container: "body"
            });

            $('.alert .close').click(function (e) {
                e.preventDefault();
                $(this).parents('.alert').fadeOut(300);
            });

            $(document).on('click', ".toggle-origin", function (e) {
                this.nextElementSibling.value++;
            });

            $(document).on('click', ".toggle-boolean", function (e) {
                var that = this,
                    $this = $(this),
                    field = $this.data('field'),
                    data = {},
                    value = this.attributes['data-value'].value,
                    xhr = new XMLHttpRequest();

                data[field] = value == 'true' ? false : true

                xhr.open("POST", $this.data('url'), true);
                xhr.setRequestHeader("Content-Type", "application/json");
                xhr.onload = function () {
                    if (xhr.status === 200) {
                        var response = JSON.parse(xhr.responseText);
                        $this.attr('data-value', response[field]);
                    } else {
                        $this.attr('data-value', value);
                    }
                    setupToggleBoolean(that);
                };
                xhr.onerror = function () {
                    setupToggleBoolean(that);
                };
                this.previousElementSibling.innerHTML = '<i class="fa fa-spinner fa-spin fa-fw"></i>';
                this.innerHTML = '<i class="fa fa-toggle-' + (data[field] ? 'on' : 'off') + '"></i>';
                xhr.send(JSON.stringify(data));
            });
            $.propHooks.disabled = {
                set: function (el, value) {
                    if (el.disabled !== value) {
                        el.disabled = value;
                        $(el).trigger(value ? 'disabled' : 'enabled');
                    }
                }
            };
            $(".soc-btn").on("click", function (ev) {
                $(this).addClass("selected");
                $(this).siblings().addClass("unused");

                var parent = $(this).parent().parent().parent();
                console.log($(parent));

                var forms = $(parent).find('form');
                $(forms).each(function () {
                    $(this).find("input, button").not(':hidden')
                        .prop("disabled", true);
                });

                $(this).prop("disabled", false);

                var links = $(parent).find('a');
                $(links).each(function () {
                    $(this).on('click', function (ev) {
                        ev.preventDefault();
                    });
                });
            });
        },

        initializing = function () {
            $('pre code').each(function (i, block) {
                hljs.highlightBlock(block);
            });

            if ($(window).width() > 767) {
                $("#wrapper").addClass('toggled');
                $("#sidebar-toggle").addClass('toggled');
            }
            if (getAbsolute()) {
                $(".social-links").addClass("absolute");
            }
            if ($('#setup_scheduler_expression_field').length > 0) {
                //  schedulerInit();

                if ($('.scheduler_type').length > 0) {
                    $('.scheduler_type').each(function () {
                        schedulerInit($(this));
                    })
                }
            }

            if ($('#setup_algorithm_store_output').length > 0)
                algorithmInit();

            if ($('.select-tag').length > 0)
                selectTagsInit();

            if ($('.select-tag-no-add').length > 0) {
                $('.select-tag-no-add').select2({
                    theme: "bootstrap",
                    tags: true,
                    createTag: function (params) {
                        // Don't offset to create a tag if there is no @ symbol
                        if (params.term.indexOf('@') === -1) {
                            // Return null to disable tag creation
                            return null;
                        }

                        return {
                            id: params.term,
                            text: params.term
                        }
                    }
                })
            }

            if ($('.remove_data_type_actions').length > 0) {
                cenitOauthScopeInit();
            }

            if ($('select.input-sm', '.graphics-controls').length > 0)
                graphicsInit();

            updateModelCountOneByOneNoChild();

            if ($('.dashboard').length > 0)
                updateDashboardCount();

            slideshow.initialize();

            $('.auto-complete').each(function () {
                setupAutoComplete(this);
            });

            $('.toggle-boolean').each(function () {
                $('<span></span>').insertBefore(this);
                setupToggleBoolean(this);
            });
            if ($('#home_page').length > 0) {
                initHomePage();
            }
            // Layout and Sidebars initialization

            initRelatedMenu();
            // checking for minified left sidebar
            checkMinified();

            // slimscroll left navigation
            if ($('body.sidebar-fixed').length > 0) {
                $('body.sidebar-fixed .sidebar-scroll').slimScroll({
                    height: '100%',
                    wheelStep: 5,
                });
            }

            update_active_nav_link();
        },

        // Module exposed functions

        initModule = function () {

            // Initialization
            initializing();

            // Register events handlers
            registerEvents();

        };

    return {initModule: initModule};

}(jQuery));