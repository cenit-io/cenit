function schedulerInit() {
    var top_level = $('#setup_scheduler_expression_field');
    var is_scheduler = top_level.length > 0;
    if (!is_scheduler) {
        return;
    }

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

    function zP(val, n) {
        return ('0' * n + val).slice(-n);
    }

    function validateNumberInput(input) {
        var min = parseInt($(input).attr('min'));
        var max = parseInt($(input).attr('max'));
        $(input).val(ensureInRange($(input).val(), min, max));
    }

    function daysInMonth(month, year) {
        return new Date(year, month, 0).getDate();
    }

    $('input[type=number]').on('input', function () {
        validateNumberInput(this);
    });

    $('#start_year, #start_month').on('input change', function () {
        var year = parseInt($('#start_year').val());
        var month = parseInt($('#start_month').val());
        var max = daysInMonth(month, year);

        var day_input = '#start_day';
        $(day_input).attr('max', max);
        validateNumberInput(day_input);
    });

    $('#end_year, #end_month').on('input change', function () {
        var year = parseInt($('#end_year').val());
        var month = parseInt($('#end_month').val());
        var max = daysInMonth(month, year);
        var input = '#end_day';
        $(input).attr('max', max);
        validateNumberInput(input);
    });

    $('#hours_sl').on('change', function () {
        $('#hours_every').toggleClass('hidden');
        $('#hours_at').toggleClass('hidden');
    });

    $('#days_sl').on('change', function () {
        var value = $(this).val();

        $('#days_0').addClass('hidden');
        $('#days_1').addClass('hidden');
        $('#days_2').addClass('hidden');

        $('#days_' + value).removeClass('hidden');
    });

    $('#weeks_sl').on('change', function () {
        $('#weeks_0').toggleClass('hidden');
        $('#weeks_1').toggleClass('hidden');
    });

    $('#months_sl').on('change', function () {
        $('#months_0').toggleClass('hidden');
        $('#months_1').toggleClass('hidden');
    });

    $('#start_sl').on('change', function () {
        var value = $(this).val();

        $('#start_1').addClass('hidden');
        $('#start_2').addClass('hidden');

        $('#start_' + value).removeClass('hidden');
    });

    $('#end_sl').on('change', function () {
        var value = $(this).val();

        $('#end_1').addClass('hidden');
        $('#end_2').addClass('hidden');

        $('#end_' + value).removeClass('hidden');
    });

    function updateExpression() {
        var res = {};

        switch ($('#start_sl').val()) {
            case "1":
                res["start_at"] = "YYYY-MM-DD HH:mm"
                    .replace('YYYY', $('#start_year').val())
                    .replace('MM', zP($('#start_month').val(), 2))
                    .replace('DD', zP($('#start_day').val(), 2))
                    .replace('HH', zP($('#start_hr').val(), 2))
                    .replace('mm', zP($('#start_min').val(), 2))
        }

        switch ($('#end_sl').val()) {
            case "1":
                res['end_at'] = "YYYY-MM-DD HH:mm"
                    .replace('YYYY', $('#end_year').val())
                    .replace('MM', zP($('#end_month').val(), 2))
                    .replace('DD', zP($('#end_day').val(), 2))
                    .replace('HH', zP($('#end_hr').val(), 2))
                    .replace('mm', zP($('#end_min').val(), 2));
                break;
            case "2":
                res['max_repeat'] = parseInt($("max_repeat").val());
                break;
        }

        var level = parseInt(freq_sel.val());
        var every = "";

        if (level == 1) {
            res["type"] = 'cyclic';
            res["cyclic_expression"] = $('#cyclic_num').val() + ($('#cyclic_unit').val());
        } else {
            res["type"] = 'appointed';
            if (level >= 2) {
                res["hours"] = _.filter(_.range(0, 23), function (e) {
                    return $("#hours_at_" + e).hasClass("btn-primary");
                });
                res["minutes"] = _.filter(_.range(0, 60, 5), function (e) {
                    return $("#minutes_at_" + e).hasClass("btn-primary");
                });
            }
            if (level >= 3) {
                var dval = $("#days_sl").val();
                if (dval == "1") {
                    res["week_days"] = _.filter(_.range(0, 7), function (e) {
                        return $("#week_day_" + e).hasClass("btn-primary");
                    });

                    res["weeks_month"] = _.filter(_.range(0, 3), function (e) {
                        return $("#weeks_monthly_at_" + e).hasClass("btn-primary");
                    });
                    res["last_week_in_month"] = $('#last_week_in_month').hasClass("btn-primary");
                } else {
                    res["month_days"] = _.filter(_.range(0, 31), function (e) {
                        return $("#months_day_" + e).hasClass("btn-primary");
                    });
                    res["last_day_in_month"] = $('#last_day_in_month').hasClass("btn-primary");
                }
            }
            if (level >= 4) {
                res["months"] = _.filter(_.range(1, 13), function (e) {
                    return $("#month_" + e).hasClass("btn-primary");
                });
            }
        }
        $("#setup_scheduler_expression").val(JSON.stringify(res));
    }

    updateExpression();

    // function fillInput(lbond, ubond, id) {
    //     var sel = $("#" + id);
    //     var rc = _.range(lbond, ubond, sel.val());
    //     sel.parent().find('.scheduler-opts a.btn').each(function(k,v){
    //         $(v).removeClass('btn-primary');
    //         $(v).addClass('btn-default');
    //
    //         if (rc.indexOf(k+1) != -1) {
    //             $(v).removeClass('btn-default');
    //             $(v).addClass('btn-primary');
    //         }
    //     });
    //     // $("#" + id + "_input").val(_.join(_days, ", "));
    // }
    //
    // $('#hourly').on('change', function(){
    //     $('#hours_every').toggleClass('hidden');
    //     $('#hours_at').toggleClass('hidden');
    // });
    //
    // $("#months_days").change(function (p) {
    //     fillInput(1, 33, "months_days");
    //     updateSchedulerValue();
    // });
    //
    // $("#months").change(function (p) {
    //     fillInput(1, 13, "months");
    //     updateSchedulerValue();
    // });
    //
    // $("#hours").change(function (p) {
    //     fillInput(0, 24, "hours");
    //     updateSchedulerValue();
    // });
    //
    // $("#minutes").change(function (p) {
    //     fillInput(0, 60, "minutes");
    //     updateSchedulerValue();
    // });
    //
    // $(":checkbox").change(function (p) {
    //     updateSchedulerValue();
    // });
    //
    // $(":text").change(function (p) {
    //     updateSchedulerValue();
    // });

    // $("#scheduler_kinds").change(function (p) {
    //     if ($("#scheduler_kinds").val() === "1") {
    //         cyclic.show();
    //         appointed.hide();
    //     } else {
    //         cyclic.hide();
    //         appointed.show();
    //     }
    //     updateSchedulerValue();
    // });

    // $('#weekly').click(function(e){
    //     e.preventDefault();
    //     if ($(this).hasClass('btn-primary')){
    //         $('#number').removeClass('hidden');
    //         $('#position').addClass('hidden');
    //     } else {
    //         $('#position').removeClass('hidden');
    //         $('#number').addClass('hidden');
    //     }
    //     $(this).toggleClass('btn-primary');
    //     $(this).toggleClass('btn-default');
    //
    //     updateSchedulerValue();
    // });

    // function createSchedulerValue() {
    //     function input_validation(id) {
    //         return $(id).val().indexOf(",") != -1 ?
    //             _.map($(id).val().split(","), function (e) {
    //                 return Number(e);
    //             }) : ($(id).val().trim() == "" ?
    //             [] : [Number($(id).val().trim())])
    //     }
    //
    //     var position_tab = $("#weekly").hasClass('btn-primary');
    //
    //     var cyclic_tab = $("#scheduler_kinds").val() === "1";
    //
    //     var res = {
    //
    //         "type": cyclic_tab ? "cyclic" : "appointed_" + (position_tab ? "position" : "number"),
    //
    //         "months_days": _.filter(_.range(1, 32), function (e) {
    //             return $("#months_day_" + e).hasClass("btn-primary");
    //         }),
    //             // input_validation("#months_days_input"),
    //
    //         "weeks_days": _.filter(_.range(0, 7), function (e) {
    //             return $("#week_day_" + e).hasClass("btn-primary");
    //         }),
    //
    //         "weeks_month": _.concat(_.filter(_.range(1, 5), function (e) {
    //                 return $("#week_month_" + e).hasClass("btn-primary");
    //             }),
    //             _.map(_.filter(_.range(1, 2), function (e) {
    //                 return $("#week_month_reverse_" + e).hasClass("btn-primary");
    //             }), function (e) {
    //                 return e * -1;
    //             })),
    //
    //         "last_day_in_month": $("#last_day_in_month").hasClass("btn-primary"),
    //
    //         "months": _.filter(_.range(1, 12), function (e) {
    //             return $("#month_" + e).hasClass("btn-primary");
    //         }),
    //             // input_validation("#months_input"),
    //
    //         "hours": input_validation("#hours_input"),
    //
    //         "minutes": input_validation("#minutes_input")
    //     };
    //
    //     if (cyclic_tab)
    //         res["cyclic_expression"] = $("#cyclic_expression").val();
    //
    //     return res;
    // }

    // var position_scheduler_month_days = $("#position_scheduler_month_days");
    // var number_scheduler_month_days = $("#number_scheduler_month_days");
    // var type_of_days_btn = $("#type_of_days_btn");

    // appointed.find('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
    //     updateSchedulerValue();
    // });

    // function updateSchedulerValue() {
    //     $("#setup_scheduler_expression").val(JSON.stringify(createSchedulerValue()));
    // }

}
