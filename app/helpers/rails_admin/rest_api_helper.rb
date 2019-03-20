module RailsAdmin
  ###
  # Generate sdk code for api service.
  module RestApiHelper
    include RailsAdmin::RestApi::Curl
    include RailsAdmin::RestApi::Php
    include RailsAdmin::RestApi::Ruby
    include RailsAdmin::RestApi::Python
    include RailsAdmin::RestApi::Nodejs
    include RailsAdmin::RestApi::JQuery

    def api_langs
      [
        { id: 'curl', label: 'Curl', hljs: 'bash', runnable: true },
        { id: 'php', label: 'Php', hljs: 'php', runnable: false },
        { id: 'ruby', label: 'Ruby', hljs: 'ruby', runnable: true },
        { id: 'python', label: 'Python', hljs: 'python', runnable: true },
        { id: 'nodejs', label: 'Nodejs', hljs: 'javascript', runnable: true },
        { id: 'jquery', label: 'JQuery', hljs: 'javascript', runnable: false },
      ]
    end

    ###
    # Returns api specification paths for current namespace and model.
    def api_current_paths
      @params ||= params
      if @params[:action] == 'dashboard'
        @params[:model_name] = 'cross_shared_collection'
        abstract_model = RailsAdmin::AbstractModel.new(Setup::CrossSharedCollection.to_s)
        @properties = abstract_model.properties
      end

      @api_current_paths = (@params[:model_name].present? || @data_type) ? begin
        ns, model_name, display_name = api_model

        {
          "#{ns}/#{model_name}" => {
            get: api_spec_for_list(display_name),
            post: api_spec_for_create(display_name)
          },
          "#{ns}/#{model_name}/{id}" => {
            get: api_spec_for_get(display_name),
            post: api_spec_for_update(display_name),
            delete: api_spec_for_delete(display_name)
          },
          "#{ns}/#{model_name}/{id}/{view}" => {
            get: api_spec_for_get_with_view(display_name)
          }
        }
      end : {}

    rescue Exception => ex
      {}
    end

    ###
    # Returns data and login.
    def api_data(lang, method, path, with_auth_vars=false)
      # Get parameters definition.
      query_parameters = api_parameters(method, path, 'query')

      # Get data object from query parameters.
      data = query_parameters.map { |p| [p[:name], api_default_param_value(p)] }.to_h

      uri = api_uri(method, path)

      path_parameters = api_parameters(method, path, 'path')
      vars = {}

      if with_auth_vars
        # Get login account or user.
        login = Account.current || User.current
        vars[:tenant_access_key] = login.present? ? login.key : '...'
        vars[:tenant_access_token] = login.present? ? login.token : '...'
      end

      # Set value of uri path parameters
      path_parameters.each do |p|
        var = "{#{p[:name]}}"
        if uri.match(var)
          vars[p[:name]] = @object && @object.respond_to?(p[:name]) ? @object.send(p[:name]).to_s : '...'
          uri.gsub!(var, api_inline_var(lang, p[:name]))
        end
      end

      [data, uri, vars]
    end

    ###
    # Returns lang command for service with given method and path.
    def api_code(lang, method, path, with_auth_vars=false)
      send("api_#{lang}_code", method, path, with_auth_vars)
    end

    ###
    # Returns vars definition in given lang.
    def api_auth_vars(lang, with_tokens=true)
      # Get login account or user.
      login = Account.current || User.current

      api_vars(lang, {
        tenant_access_key: (with_tokens && login.present?) ? login.key : '...',
        tenant_access_token: (with_tokens && login.present?) ? login.token : '...'
      })
    end

    ###
    # Returns vars definition in given lang.
    def api_vars(lang, vars)
      method = "api_#{lang}_vars"
      vars = respond_to?(method) ? send(method, vars) : vars.map { |k, v| "#{k} = '#{vars.is_a?(Hash) ? v : "..."}'" }
      vars.join("\n")
    end

    ###
    # Returns inline var access.
    def api_inline_var(lang, name)
      method = "api_#{lang}_inline_var"
      respond_to?(method) ? send(method, name) : "${#{name}}"
    end

    def highlight_quotation_marks(text)
      text.gsub(/'([^']+)'/, '<i><b>\1</b></i>').html_safe
    end

    protected

    ###
    # Returns parameters for service with given method and path.
    def api_parameters(method, path, _in = 'path')
      parameters = @api_current_paths[path][method][:parameters] || []
      parameters.select { |p| p[:in] == _in }
    end

    ###
    # Returns default value from parameter.
    def api_default_param_value(param)
      values = {
        'integer' => 0, 'number' => 0, 'real' => 0, 'boolean' => false, 'object' => {}, 'array' => [],
        'bson::objectid' => '', 'mongoid::boolean' => false
      }

      return param[:default] unless param[:default].nil?
      return values[param[:type]] unless values[param[:type]].nil?
      return ''
    end

    ###
    # Returns api uri.
    def api_uri(method, path)
      path_parameters = api_parameters(method, path, 'path')
      uri = "#{Cenit.homepage}/api/v2/#{path}"

      # Set value of uri path parameters
      path_parameters.each do |p|
        if @object.respond_to?(p[:name])
          value = @object.send(p[:name]).to_s
          uri.gsub!("{#{p[:name]}}", value) unless value.empty?
        end
      end if @object

      "#{uri}.json"
    end

    ###
    # Returns service get specification.
    def api_spec_for_get(display_name)
      {
        tags: [display_name],
        summary: "Retrieve an existing '#{display_name}'",
        description: [
          "Retrieves the details of an existing '#{display_name}'.",
          "You need only supply the unique '#{display_name}' identifier",
          "that was returned upon '#{display_name}' creation."
        ].join(' '),
        parameters: [{ description: 'Identifier', in: 'path', name: 'id', type: 'string', required: true }]
      }
    end

    ###
    # Returns service get specification with view parameter.
    def api_spec_for_get_with_view(display_name)
      {
        tags: [display_name],
        summary: "Retrieve one attribute of an existing '#{display_name}'",
        description: "Retrieves one attribute of an existing '#{display_name}'.",
        parameters: [
          { description: 'Identifier', in: 'path', name: 'id', type: 'string', required: true },
          { description: 'Attribute name', in: 'path', name: 'view', type: 'string', required: true }
        ]
      }
    end

    ###
    # Returns service delete specification.
    def api_spec_for_delete(display_name)
      {
        tags: [display_name],
        summary: "Delete an existing '#{display_name}'",
        description: "Permanently deletes an existing '#{display_name}'. It cannot be undone.",
        parameters: [
          { description: 'Identifier', in: 'path', name: 'id', type: 'string', required: true }
        ]
      }
    end

    ###
    # Returns service list specification.
    def api_spec_for_list(display_name)
      limit = Kaminari.config.default_per_page

      {
        tags: [display_name],
        summary: "Retrieve all existing '#{display_name.pluralize}'",
        description: "Retrieve all existing '#{display_name.pluralize}' you have previously created.",
        parameters: [
          { description: 'Page number', in: 'query', name: 'page', type: 'integer', default: 1 },
          { description: 'Page size', in: 'query', name: 'limit', type: 'integer', default: limit },
          { description: 'Items order', in: 'query', name: 'order', type: 'string', default: 'id' },
        ]
      }
    end

    ###
    # Returns service create specification.
    def api_spec_for_create(display_name)
      @parameters ||= api_params_from_model_properties

      {
        tags: [display_name],
        summary: "Create an '#{display_name}'",
        description: [
          "Creates the specified '#{display_name}'.",
          'Any parameters not provided will be left unchanged.'
        ].join(' '),
        parameters: @parameters.select { |p| !p[:name].match(/^id$/) }
      }
    end

    ###
    # Returns service update specification.
    def api_spec_for_update(display_name)
      @parameters ||= api_params_from_model_properties

      {
        tags: [display_name],
        summary: "Update an '#{display_name}'",
        description: [
          "Updates the specified '#{display_name}'.",
          'Any parameters not provided will be left unchanged.'
        ].join(' '),
        parameters: [
          { description: 'Identifier', in: 'path', name: 'id', type: 'string' }
        ] + @parameters.select { |p| !p[:name].match(/^id$/) }
      }
    end

    ###
    # Returns prepared parameters from model properties.
    # TODO Review the useful of this method
    def api_params_from_model_properties
      exclude = /^(created_at|updated_at|version|origin)$|_ids|_type?$/
      parameters = []
      @properties.each do |p|
        next if p.is_a?(RailsAdmin::MongoffAssociation)
        name, type = p.is_a?(RailsAdmin::MongoffProperty) ?
          [p.property, p.type.to_s] :
          [p.property.name, p.property.type.name.downcase]

        parameters <<
          {
            in: 'query',
            name: name == '_id' ? 'id' : name,
            type: type
          }
      end
      parameters.select { |p| !p[:name].match(exclude) }
    end

    ###
    # Returns current namespace, model name and display name.
    def api_model
      @params ||= params
      if @data_type
        ns = Setup::Namespace.where(name: @data_type.namespace).first
        ns = ns ? ns.slug : @data_type.namespace.parameterize.underscore.downcase
        model_name = @data_type.slug
        display_name = @data_type.name.chomp('.json').underscore.humanize
      elsif @params[:model_name]
        ns = 'setup'
        model_name = @params[:model_name]
        display_name = model_name.underscore.humanize
      end

      [ns, model_name, display_name]
    end
  end
end
