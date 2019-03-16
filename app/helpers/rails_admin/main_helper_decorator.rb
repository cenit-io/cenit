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
        options = { index: duplet[0] }
        filter_for_field = duplet[1]
        filter_name = filter_for_field.keys.first
        filter_hash = filter_for_field.values.first
        unless (field = filterable_fields.find { |f| f.name == filter_name.to_sym })
          fail "#{filter_name} is not currently filterable; filterable fields are #{filterable_fields.map(&:name).join(', ')}"
        end
        case field.filter_type
        when :enum
          #Patch
          options[:select_options] = options_for_select(field.with(object: @abstract_model.model.new).filter_enum, filter_hash['v'])
        when :date, :datetime, :time
          options[:datetimepicker_format] = field.parser.to_momentjs
        end
        options[:label] = field.label
        options[:name] = field.name
        options[:type] = field.filter_type
        options[:value] = filter_hash['v'].to_s #Patch Better String when value is a BSON::ObjectId foe instead
        options[:label] = field.label
        options[:operator] = filter_hash['o']
        %{$.filters.append(#{options.to_json});}
      end.join("\n").html_safe if ordered_filters
    end

    def filterable_fields
      @filterable_fields ||= @model_config.filter_fields
    end

    def with_cache_key?(key)
      key = "@@_#{key}"
      RailsAdmin::MainController.class_variable_defined?(key)
    rescue
      false
    end

    def with_cache_key(key, value = nil, &block)
      key = "@@_#{key}"
      if RailsAdmin::MainController.class_variable_defined?(key)
        cache = RailsAdmin::MainController.class_variable_get(key)
      else
        cache = value || block.call
        RailsAdmin::MainController.class_variable_set(key, cache)
      end
      cache
    rescue
      value || block.call
    end

    def with_cache_user_key(key, value = nil, &block)
      with_cache_key(cache_user_key(key), value, &block)
    end

    def with_cache_user_key?(key)
      with_cache_key?(cache_user_key(key))
    end

    def cache_user_key(key)
      user_key =
        if (user = User.current)
          if user.super_admin?
            :super_admin
          else
            :admin
          end
        else
          :anonymous
        end
      "#{key}_#{user_key}"
    end
  end
end
