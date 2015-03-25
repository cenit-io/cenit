(function ($) {

    var triggers;

    $.triggers = triggers = {
        options: {
            regional: {
                datePicker: {
                    dateFormat: 'dd/mm/yy'
                }
            }
        },

        load_defaults: function (model_name) {
            var model_fields = fields[model_name];
            for (var p in default_triggers) {
                for (var i = 0; i < model_fields.length; i++) {
                    if (model_fields[i][1] == p) {
                        var field = model_fields[i];
                        var field_triggers = default_triggers[p];
                        for (var index in field_triggers) {
                            var field_value = field_triggers[index]['v'];
                            var options = '';
                            for (var j = 0; j < field[2].length; j++) {
                                var option = field[2][j];
                                var selected = (field_value == option || (Array.isArray(field_value) && field_value.indexOf(option) != -1) ? 'selected' : '');
                                options += "<option value=" + field[2][j] + " " + selected + ">" + field[2][j] + "</option> ";
                            }
                            if (index != null)
                                $.triggers.append(field[0], field[1], field[3], field_value, field_triggers[index]['o'], options, index);
                        }
                        i = model_fields.length;
                    }
                }
            }
        },

        append: function (field_label, field_name, field_type, field_value, field_operator, field_options, index) {
//            var value_name = 'a[triggers][' + field_name + '][v]';
//            var operator_name = 'a[triggers][' + field_name + '][o]';
            var value_name = 'setup_observer[triggers][' + field_name + '][' + index + '][v]';
            var operator_name = 'setup_observer[triggers][' + field_name + '][' + index + '][o]';
            var common_options = '<option ' + (field_operator == "_not_null" ? 'selected="selected"' : '') + ' value="_not_null">' + RailsAdmin.I18n.t("is_present") + '</option>' +
                '<option ' + (field_operator == "_null" ? 'selected="selected"' : '') + ' value="_null" >' + RailsAdmin.I18n.t("is_blank") + '</option>' +
                '<option ' + (field_operator == "_change" ? 'selected="selected"' : '') + ' value="_change"  >' + RailsAdmin.I18n.t("change") + '</option>';
            switch (field_type) {
                case 'boolean':
                    var control = '<select class="input-small" name="' + value_name + '">' +
                        '<option value="true"' + (field_value == "true" ? 'selected="selected"' : '') + '>' + RailsAdmin.I18n.t("true") + '</option>' +
                        '<option value="false"' + (field_value == "false" ? 'selected="selected"' : '') + '>' + RailsAdmin.I18n.t("false") + '</option>' +
                        '<option disabled="disabled">---------</option>' +
                        common_options +
                        '</select>';
                    break;
                case 'date':
                case 'datetime':
                case 'timestamp':
                    var control = '<select class="switch-additionnal-fieldsets input-small" name="' + operator_name + '">' +
                        '<option ' + (field_operator == "default" ? 'selected="selected"' : '') + ' data-additional-fieldset="default" value="default">' + RailsAdmin.I18n.t("date") + '</option>' +
                        '<option ' + (field_operator == "between" ? 'selected="selected"' : '') + ' data-additional-fieldset="between" value="between">' + RailsAdmin.I18n.t("between_and_") + '</option>' +
                        '<option ' + (field_operator == "today" ? 'selected="selected"' : '') + ' value="today">' + RailsAdmin.I18n.t("today") + '</option>' +
                        '<option ' + (field_operator == "yesterday" ? 'selected="selected"' : '') + ' value="yesterday">' + RailsAdmin.I18n.t("yesterday") + '</option>' +
                        '<option ' + (field_operator == "this_week" ? 'selected="selected"' : '') + ' value="this_week">' + RailsAdmin.I18n.t("this_week") + '</option>' +
                        '<option ' + (field_operator == "last_week" ? 'selected="selected"' : '') + ' value="last_week">' + RailsAdmin.I18n.t("last_week") + '</option>' +
                        '<option disabled="disabled">---------</option>' +
                        common_options +
                        '</select>'
                    var additional_control =
                        '<input class="date additional-fieldset default input-small" style="display:' + ((!field_operator || field_operator == "default") ? 'inline-block' : 'none') + ';" type="text" name="' + value_name + '[]" value="' + (field_value[0] || '') + '" /> ' +
                        '<input placeholder="-∞" class="date additional-fieldset between input-small" style="display:' + ((field_operator == "between") ? 'inline-block' : 'none') + ';" type="text" name="' + value_name + '[]" value="' + (field_value[1] || '') + '" /> ' +
                        '<input placeholder="∞" class="date additional-fieldset between input-small" style="display:' + ((field_operator == "between") ? 'inline-block' : 'none') + ';" type="text" name="' + value_name + '[]" value="' + (field_value[2] || '') + '" />';
                    break;
                case 'enum':
                    var multiple_values = ((field_value instanceof Array) ? true : false)
                    var control = '<select style="display:' + (multiple_values ? 'none' : 'inline-block') + '" ' + (multiple_values ? '' : 'name="' + value_name + '"') + ' data-name="' + value_name + '" class="select-single input-small">' +
                        common_options +
                        '<option disabled="disabled">---------</option>' +
                        field_options +
                        '</select>' +
                        '<select multiple="multiple" style="display:' + (multiple_values ? 'inline-block' : 'none') + '" ' + (multiple_values ? 'name="' + value_name + '[]"' : '') + ' data-name="' + value_name + '[]" class="select-multiple input-small">' +
                        field_options +
                        '</select> ' +
                        '<a href="#" class="switch-select"><i class="icon-' + (multiple_values ? 'minus' : 'plus') + '"></i></a>';
                    break;
                case 'string':
                case 'text':
                case 'belongs_to_association':
                    var control = '<select class="switch-additionnal-fieldsets input-small" value="' + field_operator + '" name="' + operator_name + '">' +
                        '<option data-additional-fieldset="additional-fieldset"' + (field_operator == "like" ? 'selected="selected"' : '') + ' value="like">' + RailsAdmin.I18n.t("contains") + '</option>' +
                        '<option data-additional-fieldset="additional-fieldset"' + (field_operator == "is" ? 'selected="selected"' : '') + ' value="is">' + RailsAdmin.I18n.t("is_exactly") + '</option>' +
                        '<option data-additional-fieldset="additional-fieldset"' + (field_operator == "starts_with" ? 'selected="selected"' : '') + ' value="starts_with">' + RailsAdmin.I18n.t("starts_with") + '</option>' +
                        '<option data-additional-fieldset="additional-fieldset"' + (field_operator == "ends_with" ? 'selected="selected"' : '') + ' value="ends_with">' + RailsAdmin.I18n.t("ends_with") + '</option>' +
                        '<option disabled="disabled">---------</option>' +
                        common_options +
                        '</select>'
                    var additional_control = '<input class="additional-fieldset input-small" style="display:' + (field_operator == "_null" || field_operator == "_not_null" || field_operator == "_change" ? 'none' : 'inline-block') + ';" type="text" name="' + value_name + '" value="' + field_value + '" /> ';
                    break;
                case 'integer':
                case 'decimal':
                case 'float':
                    var control = '<select class="switch-additionnal-fieldsets input-small" name="' + operator_name + '">' +
                        '<option ' + (field_operator == "default" ? 'selected="selected"' : '') + ' data-additional-fieldset="default" value="default">' + RailsAdmin.I18n.t("Number ...") + '</option>' +
                        '<option ' + (field_operator == "between" ? 'selected="selected"' : '') + ' data-additional-fieldset="between" value="between">' + RailsAdmin.I18n.t("between_and_") + '</option>' +
                        '<option disabled="disabled">---------</option>' +
                        common_options +
                        '</select>'
                    var additional_control =
                        '<input class="additional-fieldset default input-small" style="display:' + ((!field_operator || field_operator == "default") ? 'inline-block' : 'none') + ';" type="' + field_type + '" name="' + value_name + '[]" value="' + (field_value[0] || '') + '" /> ' +
                        '<input placeholder="-∞" class="additional-fieldset between input-small" style="display:' + ((field_operator == "between") ? 'inline-block' : 'none') + ';" type="' + field_type + '" name="' + value_name + '[]" value="' + (field_value[1] || '') + '" /> ' +
                        '<input placeholder="∞" class="additional-fieldset between input-small" style="display:' + ((field_operator == "between") ? 'inline-block' : 'none') + ';" type="' + field_type + '" name="' + value_name + '[]" value="' + (field_value[2] || '') + '" />';
                    break;
                default:
                    var control = '<input type="text" class="input-small" name="' + value_name + '" value="' + field_value + '"/> ';
                    break;
            }

            var content = '<p class="trigger form-search">' +
                '<span class="label label-info form-label"><a href="#" class="delete"><i class="icon-trash icon-white"></i></a> ' + field_label + '</span> ' +
                control + " " +
                (additional_control || '') +
                '</p> ';
            $('#triggers_box').append(content);
            $('#triggers_box .date').datepicker(this.options.regional.datePicker);
            $("hr.triggers_box:hidden").show('slow');
        }
    }

    $(document).on('click', "#triggers a", function (e) {
        e.preventDefault();
        $.triggers.append(
            $(this).data('field-label'),
            $(this).data('field-name'),
            $(this).data('field-type'),
            $(this).data('field-value'),
            $(this).data('field-operator'),
            $(this).data('field-options'),
            $.now().toString().slice(6, 11)
        );
        $("#triggers").hide();
    });

    $(document).on('click', "#triggers_box .delete", function (e) {
        e.preventDefault();
        form = $(this).parents('form');
        $(this).parents('.trigger').remove();
        !$("#triggers_box").children().length && $("hr.triggers_box:visible").hide('slow');
    });

    $(document).on('click', "#triggers_box .switch-select", function (e) {
        e.preventDefault();
        var selected_select = $(this).siblings('select:visible');
        var not_selected_select = $(this).siblings('select:hidden');
        not_selected_select.attr('name', not_selected_select.data('name')).show('slow');
        selected_select.attr('name', null).hide('slow');
        $(this).find('i').toggleClass("icon-plus icon-minus")
    });

    $(document).on('change', "#triggers_box .switch-additionnal-fieldsets", function (e) {
        var selected_option = $(this).find('option:selected');
        if (klass = $(selected_option).data('additional-fieldset')) {
            $(this).siblings('.additional-fieldset:not(.' + klass + ')').hide('slow');
            $(this).siblings('.' + klass).show('slow');
        } else {
            $(this).siblings('.additional-fieldset').hide('slow');
        }
    });

    $(document).on('change', "#setup_observer_data_type_id", function (e) {
        if (typeof fields != 'undefined') {
            var model_name = $("#setup_observer_data_type_id").html();
            var i = model_name.indexOf('option selected="selected');
            if (i < 0) i = 0;
            model_name = model_name.substring(i = model_name.indexOf('value="', i) + 7, model_name.indexOf('"', i));
            $("#triggers_box").html('');
            var triggers_options = '';
            var model_fields = fields[model_name];
            if (model_fields != null) {
                for (var i = 0; i < model_fields.length; i++) {
                    var field = model_fields[i];
                    var options = '';
                    for (var j = 0; j < field[2].length; j++) {
                        options += "<option value=&quot;" + field[2][j] + "&quot;>" + field[2][j] + "</option> ";
                    }
                    triggers_options += '<li> <a data-field-label="' + field[0] + '" data-field-name="' + field[1] + '" data-field-options="' + options + '" data-field-type="' + field[3] + '" data-field-value="" href="#">' + field[0] + '</a></li>';
                }
                $("#triggers").html(triggers_options);
                $.triggers.load_defaults(model_name);
                $("#add_trigger").removeClass('disabled');
            } else {
                $("#add_trigger").addClass('disabled');
            }
        }
        $("#triggers").hide();
    });

    $(document).on('click', "#add_trigger", function (e) {
        if (!$("#add_trigger").hasClass('disabled')) {
            $("#triggers").show();
        }
    });

    $(document).on('click', "#new_setup_observer", function (e) {
        $("#triggers").hide();
    });

    $(document).on('click', "#edit_setup_observer", function (e) {
        $("#triggers").hide();
    });

    $(document).on('click', "#setup_observer_triggers_field", function (e) {
        $("#triggers").hide();
    });
})(jQuery);
