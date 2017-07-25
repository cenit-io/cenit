function schedulerInit() {
    var top_level = $('#setup_scheduler_expression_field');

    function zp(num) {
        if (parseInt(num) > 9)
            return num;
        return '0' + num;
    }

    var date_start_input = $('#start_date');
    var date_start = date_start_input.val();
    date_start_input.datepicker();
    date_start_input.datepicker("option", "dateFormat", "yy-mm-dd");
    date_start_input.val(date_start);

    var time_start_input = $('#start_time');
    var time_start = time_start_input.val();
    time_start_input.timepicker();
    var t = time_start.split(':');
    time_start_input.val(zp(t[0]) + ':' + zp(t[1]));

    var date_end_input = $('#end_date');
    var date_end = date_end_input.val();
    date_end_input.datepicker();
    date_end_input.datepicker("option", "dateFormat", "yy-mm-dd");
    date_end_input.val(date_end);

    var freq_sel = $('#frequency');
    top_level.addClass('selected-' + freq_sel.val());

    $('.scheduler-opts a.btn').click(function (e) {
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

                res["weeks_month"] = _.filter(_.range(0, 3), function (e) {
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
}

function algorithmInit() {
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
}

function selectTagsInit() {
    $('.select-tag').select2({theme: "bootstrap", tags: true})
}

function cenitOauthScopeInit() {
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
}


function graphicsInit() {
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
}
var graphics_handle;
function graphic_control_change(e) {
    if (graphics_handle) {
        clearTimeout(graphics_handle);
    }
    graphics_handle = setTimeout(function () {
        var $form = $('#graphics-form');
        $form.submit();
    }, 2000);
}

function drawGraphics(options) {
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
}

function handlerInit() {
    console.log("Initializing handlers");

    if ($('#setup_scheduler_expression_field').length > 0)
        schedulerInit();

    if ($('#setup_algorithm_store_output').length > 0)
        algorithmInit();

    if ($('.select-tag').length > 0)
        selectTagsInit();

    if ($('.select-tag-no-add').length > 0)
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

    if ($('.remove_data_type_actions').length > 0) {
        cenitOauthScopeInit();
    }

    if ($('select.input-sm', '.graphics-controls').length > 0)
        graphicsInit();

    $('#main-accordion .nav-stacked').on('shown.bs.collapse', updateModelCountOneByOne);

    if ($('.dashboard table').length > 0)
        updateDashboardCount();
}
// Side Menu Bar Update Model Counts Functions

function updateModelCountOneByOne(e) {
    e.stopPropagation();
    $cenit_submenu_children = $(e.currentTarget).children('li[data-model]');
    requestModelCount();
}
function requestModelCount() {
    var array_of_children = $cenit_submenu_children.toArray();
    if (array_of_children.length > 0) {
        var $this = $(array_of_children.shift());
        $cenit_submenu_children = $(array_of_children);
        getModelCountOneByOne($this, $this.data('model'), $this.data('origins'), $this.data('ext'));
    }
}
function getModelCountOneByOne($element, model_name, origins, ext) {
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
}

// DashBoard Update Model Counts Functions

function updateDashboardCount() {
    $cenit_dashboard_models = $('.progress-bar');
    $cenit_dashboard_max_model_count = -1;
    requestDashBoardModelCount();
}
function requestDashBoardModelCount() {
    var array_of_models = $cenit_dashboard_models.toArray();
    if (array_of_models.length > 0) {
        var $this = $(array_of_models.pop());
        $cenit_dashboard_models = $(array_of_models);
        getModelCountForDashBoard($this, $this.data('model'), $this.data('origins'), $this.data('ext'));
    }
}
function getModelCountForDashBoard($element, model_name, origins, ext) {
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
                        $amount.append($('<i class="fa fa-spinner fa-pulse"></i>'));
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
}
function update_dashboard_model_percents() {
    var $progress_bars = $('.progress-bar'),
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
        },
        animate_width_to = function (percent) {
            var max_percent = 2.0;
            if (percent > max_percent) {
                max_percent = percent
            }
            return parseInt(max_percent) + '%';
        };

    $progress_bars.each(function () {
        $this = $(this);
        text = $this.text();
        percent_value = percent(parseInt(text), max);
        indicator = get_indicator(percent_value);
        anim = animate_width_to(percent_value);
        $this.attr('data-animate-length', anim);
        $this.attr('data-animate-width-to', anim);
        $this.css('width', anim);
        $this.addClass('progress-bar-' + indicator);
    });
}



