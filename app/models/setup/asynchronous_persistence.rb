module Setup
  class AsynchronousPersistence < Setup::Task

    include DataUploader

    build_in_data_type

    def target_data_type
      @target_data_type ||= (
      Setup::DataType.where(id: message['data_type_id']).first ||
        fail("Data type with ID #{message['data_type_id']} not found")
      )
    end

    def ability
      @ability ||= Ability.new(User.current)
    end

    def oauth_scope
      @oauth_scope ||= (scope = message['access_scope']) && Cenit::OauthScope.new(scope)
    end

    def authorize_action(options = {})
      action = options[:action]
      klass = target_data_type.records_model
      action_symbol =
        case action
          when 'index', 'show'
            :read
          when 'new'
            :create
          else
            action.to_sym
        end
      ability.can?(action_symbol, options[:item] || options[:klass]) &&
        (oauth_scope.nil? || oauth_scope.can?(action_symbol, options[:klass] || klass))
    end

    def run(message)
      parser_options = (message['parser_options'] || {}).dup.with_indifferent_access
      parser_options[:create_callback] = -> model {
        unless authorize_action(action: :create, klass: model)
          fail "Not authorized to create records of type #{model}"
        end
      }
      parser_options[:update_callback] = -> record {
        unless authorize_action(action: :update, item: record)
          fail "Not authorized to update records of type #{record&.orm_model}"
        end
      }
      if (record_id = message['record_id'])
        unless (record = target_data_type.where(id: record_id).first)
          fail "Record with ID #{record_id} not found"
        end
        record.fill_from(data.read, parser_options)
        save_options = {}
        if record.class.is_a?(Class) && record.class < FieldsInspection
          save_options[:inspect_fields] = message['inspect_fields']
        end
        unless Cenit::Utility.save(record, save_options)
          fail "Unable to update the record: #{record.errors.full_messages.to_sentence}"
        end
      else
        parser = Api::V3::ApiController::Parser.new(target_data_type)
        parser.create_from!(data.read, parser_options)
      end
      nil
    end

    module Model
    end
  end
end
