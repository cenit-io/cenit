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
        append = function ($container, field, operator, value) {
            var item_value_name = '{0}[{1}][][v]'.format(item_name, field.name),
                item_operator_name = '{0}[{1}][][o]'.format(item_name, field.name),
                additional_control = '', control,
                common_options =
                    '<option disabled="disabled">---------</option>' +
                    '<option ' + (operator == "_not_null" ? 'selected="selected"' : '') + ' value="_not_null">' + RailsAdmin.I18n.t("is_present") + '</option>' +
                    '<option ' + (operator == "_null" ? 'selected="selected"' : '') + ' value="_null" >' + RailsAdmin.I18n.t("is_blank") + '</option>' +
                    '<option ' + (operator == "_change" ? 'selected="selected"' : '') + ' value="_change"  >' + RailsAdmin.I18n.t("change") + '</option>' +
                    '<option ' + (operator == "_presence_change" ? 'selected="selected"' : '') + ' value="_presence_change"  >' + RailsAdmin.I18n.t("present_and_change") + '</option>';

            value = value || '';
            operator = operator || '';

            switch (field.type) {
                case 'boolean':
                    control =
                        '<select class="input-sm form-control" name="' + item_value_name + '">' +
                        '<option value="_discard">...</option>' +
                        '<option value="true"' + (value == "true" ? 'selected="selected"' : '') + '>' + RailsAdmin.I18n.t("true") + '</option>' +
                        '<option value="false"' + (value == "false" ? 'selected="selected"' : '') + '>' + RailsAdmin.I18n.t("false") + '</option>' +
                        common_options +
                        '</select>';
                    break;

                case 'date':
                    additional_control =
                        '<input size="20" class="date additional-fieldset default input-sm form-control" style="display:' + ((!operator || operator == "default") ? 'inline-block' : 'none') + ';" type="text" name="' + item_value_name + '[]" value="' + (value[0] || '') + '" /> ' +
                        '<input size="20" placeholder="-∞" class="date additional-fieldset between input-sm form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="text" name="' + item_value_name + '[]" value="' + (value[1] || '') + '" /> ' +
                        '<input size="20" placeholder="∞" class="date additional-fieldset between input-sm form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="text" name="' + item_value_name + '[]" value="' + (value[2] || '') + '" />';
                case 'time':
                case 'datetime':
                case 'timestamp':
                    control = control || '<select class="switch-additionnal-fieldsets input-sm form-control" name="' + item_operator_name + '">' +
                        '<option ' + (operator == "default" ? 'selected="selected"' : '') + ' data-additional-fieldset="default" value="default">' + RailsAdmin.I18n.t("date") + '</option>' +
                        '<option ' + (operator == "between" ? 'selected="selected"' : '') + ' data-additional-fieldset="between" value="between">' + RailsAdmin.I18n.t("between_and_") + '</option>' +
                        '<option ' + (operator == "today" ? 'selected="selected"' : '') + ' value="today">' + RailsAdmin.I18n.t("today") + '</option>' +
                        '<option ' + (operator == "yesterday" ? 'selected="selected"' : '') + ' value="yesterday">' + RailsAdmin.I18n.t("yesterday") + '</option>' +
                        '<option ' + (operator == "this_week" ? 'selected="selected"' : '') + ' value="this_week">' + RailsAdmin.I18n.t("this_week") + '</option>' +
                        '<option ' + (operator == "last_week" ? 'selected="selected"' : '') + ' value="last_week">' + RailsAdmin.I18n.t("last_week") + '</option>' +
                        common_options +
                        '</select>';
                    additional_control = additional_control ||
                        '<input size="25" class="datetime additional-fieldset default input-sm form-control" style="display:' + ((!operator || operator == "default") ? 'inline-block' : 'none') + ';" type="text" name="' + item_value_name + '[]" value="' + (value[0] || '') + '" /> ' +
                        '<input size="25" placeholder="-∞" class="datetime additional-fieldset between input-sm form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="text" name="' + item_value_name + '[]" value="' + (value[1] || '') + '" /> ' +
                        '<input size="25" placeholder="∞" class="datetime additional-fieldset between input-sm form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="text" name="' + item_value_name + '[]" value="' + (value[2] || '') + '" />';
                    break;

                case 'enum':
                    var multiple_values = ((value instanceof Array) ? true : false),
                        values = multiple_values ? value : [value],
                        enum_options = field.options.map(function (opt) {
                            return '<option ' + (values.indexOf(opt) >= 0 ? 'selected="selected"' : '') + ' value="' + opt + '">' + opt + '</option>';
                        }).join('');

                    control =
                        '<select style="display:' + (multiple_values ? 'none' : 'inline-block') + '" ' + (multiple_values ? '' : 'name="' + item_value_name + '"') + ' data-name="' + item_value_name + '" class="select-single input-sm form-control">' +
                        common_options +
                        '<option disabled="disabled">---------</option>' +
                        enum_options +
                        '</select>' +
                        '<select multiple="multiple" style="display:' + (multiple_values ? 'inline-block' : 'none') + '" ' + (multiple_values ? 'name="' + item_value_name + '[]"' : '') + ' data-name="' + item_value_name + '[]" class="select-multiple form-control">' +
                        enum_options +
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
                        common_options +
                        '</select>';
                    additional_control = '<input class="additional-fieldset input-sm form-control" style="display:' + (operator == "_blank" || operator == "_present" ? 'none' : 'inline-block') + ';" type="text" name="' + item_value_name + '" value="' + value + '" /> ';
                    break;

                case 'integer':
                case 'decimal':
                case 'float':
                    control =
                        '<select class="switch-additionnal-fieldsets input-sm form-control" name="' + item_operator_name + '">' +
                        '<option ' + (operator == "default" ? 'selected="selected"' : '') + ' data-additional-fieldset="default" value="default">' + RailsAdmin.I18n.t("number") + '</option>' +
                        '<option ' + (operator == "between" ? 'selected="selected"' : '') + ' data-additional-fieldset="between" value="between">' + RailsAdmin.I18n.t("between_and_") + '</option>' +
                        common_options +
                        '</select>';
                    additional_control =
                        '<input class="additional-fieldset default input-sm form-control" style="display:' + ((!operator || operator == "default") ? 'inline-block' : 'none') + ';" type="' + field.type + '" name="' + item_value_name + '[]" value="' + (value[0] || '') + '" /> ' +
                        '<input placeholder="-∞" class="additional-fieldset between input-sm form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="' + field.type + '" name="' + item_value_name + '[]" value="' + (value[1] || '') + '" /> ' +
                        '<input placeholder="∞" class="additional-fieldset between input-sm form-control" style="display:' + ((operator == "between") ? 'inline-block' : 'none') + ';" type="' + field.type + '" name="' + item_value_name + '[]" value="' + (value[2] || '') + '" />';
                    break;

                default:
                    control = '<input type="text" class="input-sm form-control" name="' + item_value_name + '" value="' + value + '"/> ';
                    break;
            }

            var $content = $(
                '<div class="trigger">' +
                '  <span class="label label-info form-label">' +
                '    <a href="#delete" class="delete"><i class="fa fa-trash-o fa-fw icon-white"></i>' + field.label +
                '  </a></span>&nbsp;' + control + '&nbsp;' + (additional_control || '') +
                '</div> '
            );

            $container.find('.triggers-box').append($content);

            $content.find('.date, .datetime').datetimepicker({
                locale: RailsAdmin.I18n.locale,
                showTodayButton: true
            });

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
            // Show or hiden additionnal fields after render trigger.
            $content.find('.switch-additionnal-fieldsets').change();
        };

        // Connect add new trigger action.
        $el.find('.triggers-menu .dropdown-item').on('click', function (e) {
            e.preventDefault();
            append($el, $(this).data('field'), null, null);
        });

        // Render saved triggers.
        fields_definition.forEach(function (field) {
            if (item_values[field.name]) {
                // Each legacy hash values or new array items format.
                $.each(item_values[field.name], function (item_index, item_value) {
                    append($el, field, item_value.o, item_value.v);
                });
            }
        });
    };

})(jQuery);
