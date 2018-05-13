var template_engine = (function ($) {
    // Module scope variables
    var
        // Set constants
        configMap = {},
        render = function (template_name, data) {
            var html = $('#' + template_name).clone().html(),
                keys = Object.keys(data), reg_exp;

            $.each(keys, function (index, value) {
                reg_exp = new RegExp("{{" + value + "}}", "g");
                html = html.replace(reg_exp, data[value]);
            });
            return $(html);
        },
        initModule = function () {
        };
    return {initModule: initModule, render: render};

}(jQuery));
