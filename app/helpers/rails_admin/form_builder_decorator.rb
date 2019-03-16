# rails_admin-1.0 ready
module RailsAdmin
  FormBuilder.class_eval do
    alias_method :rails_admin_generate, :generate

    def generate(options = {})
      rails_admin_generate(options)
    rescue Exception => ex
      Setup::SystemReport.create_from(ex)
      @template.render partial: 'form_notice', locals: { message: ex.message }
    end

    def generate_nested(field)
      key = :"[cenit]#{NestedForm}.count"
      status =
        if (nested_forms = RequestStore.store[key]) && (nested_forms > ::Cenit.max_nested_forms)
          :overflow
        else
          nested_stack_status
        end
      case status
      when :recursive, :too_deep, :overflow
        @template.render partial: 'form_notice', locals: { status: status }
      else
        RequestStore.store[key] = (nested_forms || 0) + 1
        generate({ action: :nested, model_config: field.associated_model_config, nested_in: field })
      end
    rescue Exception => ex
      Setup::SystemReport.create_from(ex)
      @template.render partial: 'form_notice', locals: { message: ex }
    end

    def nested_stack_status(nested_models = [])
      if nested_models.count >= (::Cenit.max_nested_forms_levels || 10)
        :too_deep
      elsif @object.instance_variable_get(:@_nested_form_dummy_object).to_b
        if nested_models.include?(@object.class)
          :recursive
        elsif (parent_builder = @options[:parent_builder]).is_a?(self.class)
          nested_models << @object.class
          parent_builder.nested_stack_status(nested_models)
        end
      end
    end
  end
end
