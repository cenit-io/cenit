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

        updateExpression();
    });
    top_level.find('input, select').on('input change', function () {
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

}
