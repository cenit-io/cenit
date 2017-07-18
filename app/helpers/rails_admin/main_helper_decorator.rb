# rails_admin-1.0 ready
module RailsAdmin
  MainHelper.class_eval do

    alias_method :ra_rails_admin_form_for, :rails_admin_form_for

    def rails_admin_form_for(*args, &block)
      ra_rails_admin_form_for(*args, &block)
    rescue Exception => ex
      Setup::SystemReport.create_from(ex)
      render partial: 'form_notice', locals: { message: ex }
    end

    def ordered_filter_string
      @ordered_filter_string ||= ordered_filters.map do |duplet|
        options = {index: duplet[0]}
        filter_for_field = duplet[1]
        filter_name = filter_for_field.keys.first
        filter_hash = filter_for_field.values.first
        unless (field = filterable_fields.find { |f| f.name == filter_name.to_sym })
          fail "#{filter_name} is not currently filterable; filterable fields are #{filterable_fields.map(&:name).join(', ')}"
        end
        case field.type
        when :enum
          #Patch
          options[:select_options] = options_for_select(field.with(object: @abstract_model.model.new).filter_enum, filter_hash['v'])
        when :date, :datetime, :time
          options[:datetimepicker_format] = field.parser.to_momentjs
        end
        options[:label] = field.label
        options[:name]  = field.name
        options[:type]  = field.type
        options[:value] = filter_hash['v']
        options[:label] = field.label
        options[:operator] = filter_hash['o']
        %{$.filters.append(#{options.to_json});}
      end.join("\n").html_safe if ordered_filters
    end
  end
end
