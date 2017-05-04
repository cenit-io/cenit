(function ($) {

    $.fn.triggers = function (values) {
        var $el = $(this),
            fields_definition = [],
            item_name = $el.find('.triggers-box').data('fieldName'),
            item_values = values || {};

        $el.find('.triggers-menu .dropdown-item').map(function (i, v) {
            fields_definition.push($(v).data('field'));
        });

        // TODO: Must be optimized.
        append = function (field, operator, value) {
            var item_value_name = '{0}[{1}][][v]'.format(item_name, field.name),
                item_operator_name = '{0}[{1}][][o]'.format(item_name, field.name),
                additional_control = '', control,
                common_options =
                    '<option ' + (operator == "_not_null" ? 'selected="selected"' : '') + ' value="_not_null">' + RailsAdmin.I18n.t("is_present") + '</option>' +
                    '<option ' + (operator == "_null" ? 'selected="selected"' : '') + ' value="_null" >' + RailsAdmin.I18n.t("is_blank") + '</option>' +
                    '<option ' + (operator == "_change" ? 'selected="selected"' : '') + ' value="_change"  >' + RailsAdmin.I18n.t("change") + '</option>' +
                    '<option ' + (operator == "_presence_change" ? 'selected="selected"' : '') + ' value="_presence_change"  >' + RailsAdmin.I18n.t("present_and_change") + '</option>';

            value = value || '';
            operator = operator || '';

            switch (field.type) {
                case 'boolean':
                    control =
                        '<select class="form-control" name="' + item_value_name + '">' +
                        '<option value="true"' + (value == "true" ? 'selected="selected"' : '') + '>' + RailsAdmin.I18n.t("true") + '</option>' +
                        '<option value="false"' + (value == "false" ? 'selected="selected"' : '') + '>' + RailsAdmin.I18n.t("false") + '</option>' +
                        '<option data-divider="true" disabled="true"></option>' +
                        common_options +
                        '</select>';
                    break;

                case 'date':
                case 'time':
                case 'datetime':
                case 'timestamp':
                    control =
                        '<select class="switch-additionnal-fieldsets form-control" name="' + item_operator_name + '">' +
                        '<option ' + (operator == "default" ? 'selected="selected"' : '') + ' data-additional-fieldset="default" value="default">' + RailsAdmin.I18n.t("date") + '</option>' +
                        '<option ' + (operator == "between" ? 'selected="selected"' : '') + ' data-additional-fieldset="between" value="between">' + RailsAdmin.I18n.t("between_and_") + '</option>' +
                        '<option ' + (operator == "today" ? 'selected="selected"' : '') + ' value="today">' + RailsAdmin.I18n.t("today") + '</option>' +
                        '<option ' + (operator == "yesterday" ? 'selected="selected"' : '') + ' value="yesterday">' + RailsAdmin.I18n.t("yesterday") + '</option>' +
                        '<option ' + (operator == "this_week" ? 'selected="selected"' : '') + ' value="this_week">' + RailsAdmin.I18n.t("this_week") + '</option>' +
                        '<option ' + (operator == "last_week" ? 'selected="selected"' : '') + ' value="last_week">' + RailsAdmin.I18n.t("last_week") + '</option>' +
                        '<option data-divider="true" disabled="true"></option>' +
                        common_options +
                        '</select>';
                    additional_control =
                        '<input class="date additional-fieldset default form-control" style="display:' + ((!operator || operator == "default") ? 'inline-block' : 'none') + ';" type="text" name="' + item_value_name + '[]" value="' + (value[0] || '') + '" /> ' +
                        '<input placeholder="-∞" class="date additional-fieldset between form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="text" name="' + item_value_name + '[]" value="' + (value[1] || '') + '" /> ' +
                        '<input placeholder="∞" class="date additional-fieldset between form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="text" name="' + item_value_name + '[]" value="' + (value[2] || '') + '" />';
                    break;

                case 'enum':
                    var multiple_values = ((value instanceof Array) ? true : false),
                        options = field.options.map(function (opt) {
                            '<option ' + (operator == opt ? 'selected="selected"' : '') + ' value="' + o + '">' + o + '</option>';
                        }).join('')

                    control =
                        '<select style="display:' + (multiple_values ? 'none' : 'inline-block') + '" ' + (multiple_values ? '' : 'name="' + item_value_name + '"') + ' data-name="' + item_value_name + '" class="select-single form-control">' +
                        common_options +
                        '<option data-divider="true" disabled="true"></option>' +
                        options +
                        '</select>' +
                        '<select multiple="multiple" style="display:' + (multiple_values ? 'inline-block' : 'none') + '" ' + (multiple_values ? 'name="' + item_value_name + '[]"' : '') + ' data-name="' + item_value_name + '[]" class="select-multiple form-control">' +
                        options +
                        '</select> ' +
                        '<a href="#" class="switch-select"><i class="icon-' + (multiple_values ? 'minus' : 'plus') + '"></i></a>';
                    break;

                case 'string':
                case 'text':
                case 'belongs_to_association':
                    control =
                        '<select class="switch-additionnal-fieldsets input-sm form-control" value="' + operator + '" name="' + item_operator_name + '">' +
                        '<option data-additional-fieldset="additional-fieldset"' + (operator == "like" ? 'selected="selected"' : '') + ' value="like">' + RailsAdmin.I18n.t("contains") + '</option>' +
                        '<option data-additional-fieldset="additional-fieldset"' + (operator == "is" ? 'selected="selected"' : '') + ' value="is">' + RailsAdmin.I18n.t("is_exactly") + '</option>' +
                        '<option data-additional-fieldset="additional-fieldset"' + (operator == "starts_with" ? 'selected="selected"' : '') + ' value="starts_with">' + RailsAdmin.I18n.t("starts_with") + '</option>' +
                        '<option data-additional-fieldset="additional-fieldset"' + (operator == "ends_with" ? 'selected="selected"' : '') + ' value="ends_with">' + RailsAdmin.I18n.t("ends_with") + '</option>' +
                        '<option data-divider="true" disabled="true"></option>' +
                        common_options +
                        '</select>';
                    additional_control = '<input class="additional-fieldset form-control" style="display:' + (operator == "_blank" || operator == "_present" ? 'none' : 'inline-block') + ';" type="text" name="' + item_value_name + '" value="' + value + '" /> ';
                    break;

                case 'integer':
                case 'decimal':
                case 'float':
                    control =
                        '<select class="switch-additionnal-fieldsets form-control" name="' + item_operator_name + '">' +
                        '<option ' + (operator == "default" ? 'selected="selected"' : '') + ' data-additional-fieldset="default" value="default">' + RailsAdmin.I18n.t("number") + '</option>' +
                        '<option ' + (operator == "between" ? 'selected="selected"' : '') + ' data-additional-fieldset="between" value="between">' + RailsAdmin.I18n.t("between_and_") + '</option>' +
                        '<option data-divider="true" disabled="true"></option>' +
                        common_options +
                        '</select>'
                    additional_control =
                        '<input class="additional-fieldset default form-control" style="display:' + ((!operator || operator == "default") ? 'inline-block' : 'none') + ';" type="' + field.type + '" name="' + item_value_name + '[]" value="' + (value[0] || '') + '" /> ' +
                        '<input placeholder="-∞" class="additional-fieldset between form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="' + field.type + '" name="' + item_value_name + '[]" value="' + (value[1] || '') + '" /> ' +
                        '<input placeholder="∞" class="additional-fieldset between form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="' + field.type + '" name="' + item_value_name + '[]" value="' + (value[2] || '') + '" />';
                    break;

                default:
                    control = '<input type="text" class="form-control" name="' + item_value_name + '" value="' + value + '"/> ';
                    break;
            }

            var $content = $(
                '<div class="trigger">' +
                '  <span class="label label-info form-label">' +
                '    <a href="#" class="delete"><i class="icon-trash icon-white"></i></a> ' + field.label +
                '  </span> ' + control + " " + (additional_control || '') +
                '</div> '
            );

            $el.find('.triggers-box').append($content);
            $el.find('.triggers-box .date').datepicker({regional: {datePicker: {dateFormat: 'dd/mm/yy'}}});

            // Connect events
            $content.find('.delete').on('click', function (e) {
                e.preventDefault();
                $(this).parents('.trigger').remove();
            });

            $content.find('.switch-select').on('click', function (e) {
                e.preventDefault();
                var selected_select = $(this).siblings('select:visible'),
                    not_selected_select = $(this).siblings('select:hidden');

                not_selected_select.attr('name', not_selected_select.data('name')).show('slow');
                selected_select.attr('name', null).hide('slow');
                $(this).find('i').toggleClass("icon-plus icon-minus")
            });

            $content.find('.switch-additionnal-fieldsets').on('change', function (e) {
                var selected_option = $(this).find('option:selected');
                if ((klass = selected_option.data('additional-fieldset'))) {
                    $(this).siblings('.additional-fieldset:not(.' + klass + ')').hide('slow');
                    $(this).siblings('.' + klass).show('slow');
                } else {
                    $(this).siblings('.additional-fieldset').hide('slow');
                }
            });
        };

        // Connect add new trigger action.
        $el.find('.triggers-menu .dropdown-item').on('click', function (e) {
            e.preventDefault();
            append($(this).data('field'), null, null);
        });

        // Render saved triggers.
        fields_definition.forEach(function (field) {
            if (item_values[field.name]) {
                item_values[field.name].forEach(function (item_value) {
                    append(field, item_value.o, item_value.v);
                });
            }
        });
    };

})(jQuery);
