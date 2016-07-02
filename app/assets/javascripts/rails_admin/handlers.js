function schedulerInit() {
    var top_level = $('#setup_scheduler_expression_field');
    function zp(num){
        if (parseInt(num) > 9)
            return num;
        return '0'+num;
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
    time_start_input.val(zp(t[0])+':'+zp(t[1]));

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

        if (cyclic_unit.val() == 'm'){
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
    // var output_validate = $('#setup_algorithm_validate_output');

    if (! output_store)
        return;

    function updateView() {
        output_datatype_field.addClass('hidden');
        output_validate_field.addClass('hidden');

        var store = output_store.is(':checked');
        if (store) {
            output_datatype_field.removeClass('hidden');
        }

        var dt = output_datatype.val();
        if (dt) {
            output_validate_field.removeClass('hidden');
        }
    }

    output_store.on('change', updateView);
    output_datatype.on('change', updateView);
    updateView();
}

function handlerInit() {
    console.log("Initializing handlers");

    if ($('#setup_scheduler_expression_field').length > 0)
        schedulerInit();

    if ($('#setup_algorithm_store_output').length > 0)
        algorithmInit();
}
