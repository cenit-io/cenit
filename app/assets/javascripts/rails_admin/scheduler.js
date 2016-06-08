function schedulerInit() {
    var cyclic = $("#cyclic");
    var appointed = $("#appointed");

    if ((cyclic.length == 0) || (appointed.length == 0)){
        return;
    }

    $('#appointed_tabs').tab();

    function fillInput(lbond, ubond, id) {
        var sel = $("#" + id);
        var rc = _.range(lbond, ubond, sel.val());
        sel.parent().find('.scheduler-opts a.btn').each(function(k,v){
            $(v).removeClass('btn-primary');
            $(v).addClass('btn-default');

            if (rc.indexOf(k+1) != -1) {
                $(v).removeClass('btn-default');
                $(v).addClass('btn-primary');
            }
        });
        // $("#" + id + "_input").val(_.join(_days, ", "));
    }

    $("#months_days").change(function (p) {
        fillInput(1, 33, "months_days");
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
            cyclic.show();
            appointed.hide();
        } else {
            cyclic.hide();
            appointed.show();
        }
        updateSchedulerValue();
    });

    $('#weekly').click(function(e){
        e.preventDefault();
        if ($(this).hasClass('btn-primary')){
            $('#number').removeClass('hidden');
            $('#position').addClass('hidden');
        } else {
            $('#position').removeClass('hidden');
            $('#number').addClass('hidden');
        }
        $(this).toggleClass('btn-primary');
        $(this).toggleClass('btn-default');

        updateSchedulerValue();
    });

    $('.scheduler-opts a.btn').click(function(e){
        e.preventDefault();
        $(this).toggleClass('btn-primary');
        $(this).toggleClass('btn-default');

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

        var position_tab = $("#weekly").hasClass('btn-primary');

        var cyclic_tab = $("#scheduler_kinds").val() === "1";

        var res = {

            "type": cyclic_tab ? "cyclic" : "appointed_" + (position_tab ? "position" : "number"),

            "months_days": _.filter(_.range(1, 32), function (e) {
                return $("#months_day_" + e).hasClass("btn-primary");
            }),
                // input_validation("#months_days_input"),

            "weeks_days": _.filter(_.range(0, 7), function (e) {
                return $("#week_day_" + e).hasClass("btn-primary");
            }),

            "weeks_month": _.concat(_.filter(_.range(1, 5), function (e) {
                    return $("#week_month_" + e).hasClass("btn-primary");
                }),
                _.map(_.filter(_.range(1, 2), function (e) {
                    return $("#week_month_reverse_" + e).hasClass("btn-primary");
                }), function (e) {
                    return e * -1;
                })),

            "last_day_in_month": $("#last_day_in_month").hasClass("btn-primary"),

            "months": _.filter(_.range(1, 12), function (e) {
                return $("#month_" + e).hasClass("btn-primary");
            }),
                // input_validation("#months_input"),

            "hours": input_validation("#hours_input"),

            "minutes": input_validation("#minutes_input")
        };

        if (cyclic_tab)
            res["cyclic_expression"] = $("#cyclic_expression").val();

        return res;
    }

    var position_scheduler_month_days = $("#position_scheduler_month_days");
    var number_scheduler_month_days = $("#number_scheduler_month_days");
    var type_of_days_btn = $("#type_of_days_btn");

    appointed.find('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
        updateSchedulerValue();
    });

    function updateSchedulerValue() {
        $("#setup_scheduler_expression").val(JSON.stringify(createSchedulerValue()));
    }

}
