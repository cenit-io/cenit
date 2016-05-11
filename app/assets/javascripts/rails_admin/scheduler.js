function schedulerInit() {
    $('#specific_tabs').tab();

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

    $("#scheduler_kinds").change(function (p) {
        if ($("#scheduler_kinds").val() === "1") {
            periodic.show();
            specific.hide();
        } else {
            periodic.hide();
            specific.show();
        }
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

        var position_tab = $("#position").attr('class').indexOf('active') != -1;

        var periodic_tab = $("#scheduler_kinds").val() === "1";

        var res = {

            "type": periodic_tab ? "periodic" : "specific_" + (position_tab ? "position" : "number"),

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

            "last_day_in_month": $("#last_day_in_month").is(":checked"),

            "months": input_validation("#months_input"),

            "hours": input_validation("#hours_input"),

            "minutes": input_validation("#minutes_input")
        };

        if (periodic_tab)
            res["periodic_expression"] = $("#periodic_expression").val();

        return res;
    }

    var position_scheduler_month_days = $("#position_scheduler_month_days");
    var number_scheduler_month_days = $("#number_scheduler_month_days");
    var type_of_days_btn = $("#type_of_days_btn");

    var periodic = $("#periodic");
    var specific = $("#specific");

    $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
        updateSchedulerValue();
    });

    function updateSchedulerValue() {
        $("#setup_scheduler_expression").val(JSON.stringify(createSchedulerValue()));
    }

}
