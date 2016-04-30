function schedulerInit() {

    $('#scheduler_tabs').tab();

    function fillInput(lbond, ubond, id) {
        var _days = _.range(lbond, ubond, $("#" + id).val())
        $("#" + id + "_input").val(_.join(_days, ", "));
    }

    $(":checkbox").change(function (p) {
        updateSchedulerValue();
    });

    $(":text").change(function (p) {
        updateSchedulerValue();
    });

    $("#months_days").change(function (p) {
        fillInput(1, 32, "months_days");
        updateSchedulerValue();
    });

    $("#months").change(function (p) {
        fillInput(1, 13, "months");
        updateSchedulerValue();
    });

    $("#hours").change(function (p) {
        fillInput(1, 25, "hours");
        updateSchedulerValue();
    });

    $("#minutes").change(function (p) {
        fillInput(1, 61, "minutes");
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

        var position_tab = $(".active").attr("id") == "position_tab";

        return {
            "months_days": !position_tab ? input_validation("#months_days_input") : [],

            "weeks_days": position_tab ? _.filter(_.range(0, 7), function (e) {
                return $("#week_day_" + e).is(":checked")
            }) : [],

            "weeks_month": position_tab ? _.concat(_.filter(_.range(1, 3), function (e) {
                    return $("#week_month_" + e).is(":checked")
                }),
                _.map(_.filter(_.range(1, 2), function (e) {
                    return $("#week_month_reverse_" + e).is(":checked")
                }), function (e) {
                    return e * -1;
                })) : [],

            "months": input_validation("#months_input"),

            "hours": input_validation("#hours_input"),

            "minutes": input_validation("#minutes_input")
        };
    }

    function updateSchedulerValue() {
        $("#setup_scheduler_advanced_expression").val(JSON.stringify(createSchedulerValue()));
    }

}
