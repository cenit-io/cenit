function schedulerInit() {

    $('#scheduler_tabs').tab();

    function fillInput(lbond, ubond, id) {
        var _days = _.range(lbond, ubond, $("#" + id).val());
        $("#" + id + "_input").val(_.join(_days, ", "));
    }

    $("#months_days").change(function (p) {
        fillInput(1, 32, "months_days");
        updateSchedulerValue();
    });

    $("#months").change(function (p) {
        fillInput(1, 13, "months");
        updateSchedulerValue();
    });

    $("#hours").change(function (p) {
        fillInput(0, 24, "hours");
        updateSchedulerValue();
    });

    $("#minutes").change(function (p) {
        fillInput(0, 60, "minutes");
        updateSchedulerValue();
    });

    $(":checkbox").change(function (p) {
        updateSchedulerValue();
    });

    $(":text").change(function (p) {
        updateSchedulerValue();
    });

    function createSchedulerValue() {
        function input_validation(id) {
            return $(id).val().indexOf(",") != -1 ?
                _.map($(id).val().split(","), function (e) {
                    return Number(e);
                }) : ($(id).val().trim() == "" ?
                [] : [Number($(id).val().trim())])
        }

        var position_tab = type_of_days_btn.val() == "position";

        var periodic_tab = $("#periodic").attr('class').indexOf('active') != -1;

        res = {

            "type": periodic_tab ? "periodic" : "advanced_" + (position_tab ? "position" : "number"),

            "months_days": input_validation("#months_days_input"),

            "weeks_days": _.filter(_.range(0, 7), function (e) {
                return $("#week_day_" + e).is(":checked")
            }),

            "weeks_month": _.concat(_.filter(_.range(1, 3), function (e) {
                    return $("#week_month_" + e).is(":checked")
                }),
                _.map(_.filter(_.range(1, 2), function (e) {
                    return $("#week_month_reverse_" + e).is(":checked")
                }), function (e) {
                    return e * -1;
                })),

            "months": input_validation("#months_input"),

            "hours": input_validation("#hours_input"),

            "minutes": input_validation("#minutes_input")
        };

        if (periodic_tab)
            res["periodic_expression"] = $("#periodic_expression").val();

        return res;
    }

    $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
        updateSchedulerValue();
    });

    var position_scheduler_month_days = $("#position_scheduler_month_days");
    var number_scheduler_month_days = $("#number_scheduler_month_days");
    var type_of_days_btn = $("#type_of_days_btn");

    function invertDaysMonthsTypes() {
        type_of_days_btn.val(type_of_days_btn.val() == "number" ? "position" : "number");
        type_of_days_btn.text(type_of_days_btn.val() == "number" ? "Days by number " : "Days by position ");
        type_of_days_btn.append($("<span class='caret'></span>"));
        $("#new_type_of_days_li").text(type_of_days_btn.val() == "number" ? "Days by position" : "Days by number");
        updateDaysMonths();
    }

    function updateDaysMonths() {
        number_scheduler_month_days.hide();
        position_scheduler_month_days.hide();

        if (type_of_days_btn.val() == "number") {
            number_scheduler_month_days.show();
        } else {
            position_scheduler_month_days.show();
        }

    }

    $('#new_type_of_days_btn').click(function (e) {
        invertDaysMonthsTypes();
        updateSchedulerValue();
    });

    function updateSchedulerValue() {
        $("#setup_scheduler_expression").val(JSON.stringify(createSchedulerValue()));
    }

}
