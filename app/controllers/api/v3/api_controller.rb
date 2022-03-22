module Api::V3
  class ApiController < ApplicationController

    include OAuth2AccountAuthorization
    include CorsCheck

    before_action :allow_origin_header
    before_action :authorize_account, except: [:new_user, :cors_check]
    before_action :save_request_data
    before_action :find_model, except: [:new_user, :cors_check]
    before_action :find_item, only: [:update, :show, :destroy, :digest]
    before_action :authorize_action, except: [:new_user, :cors_check]

    rescue_from Exception, with: :exception_handler

    respond_to :json

    def index
      setup_viewport
      items = select_items
      if (distinct = params[:format]&.match(/\Adistinct\((.+)\)\Z/))
        json = klass.collection.distinct(distinct[1], items.selector)
      else
        template_options.delete(:inspecting)
        if (model_ignore = klass.index_ignore_properties).present?
          template_options[:ignore] =
            if (ignore_option = template_options[:ignore])
              unless ignore_option.is_a?(Array)
                ignore_option = ignore_option.to_s.split(',').collect(&:strip)
              end
              ignore_option + model_ignore
            else
              model_ignore
            end
        end
        maximum_entries =
          if (account = Account.current)
            account.index_max_entries
          else
            Account::DEFAULT_INDEX_MAX_ENTRIES
          end
        template_options[:max_entries] =
          if (max_entries = template_options[:max_entries])
            max_entries = max_entries.to_i
            if max_entries.zero? || max_entries > maximum_entries
              maximum_entries
            else
              max_entries
            end
          else
            maximum_entries
          end
        items_data =
          if get_limit.zero?
            []
          else
            items.map do |item|
              Template.with(item) do |template|
                template.default_hash(template_options)
              end
            end
          end
        count = items.count
        json = {
          current_page: get_page,
          count: count,
          items: items_data,
          data_type: {
            (template_options[:raw_properties] ? :_id : :id) => klass.data_type.id.to_s
          }
        }
        if get_limit.positive?
          json[:total_pages] = (count * 1.0 / get_limit).ceil
        end
      end
      render json: json
    end

    def show
      item = @item
      if (json_path = request.headers['X-JSON-Path']) && json_path =~ /\A\$(.(^[.\[\]])*(\[[0-9]+\])?)+\Z/
        json_path = json_path.split('.')
        json_path.shift
        json_path.each do |access|
          index =
            if (match = access.match(/(.*)\[([0-9]+)\]\Z/))
              access = match[1]
              match[2].to_i
            end
          item =
            if item.is_a?(Array) || item.is_a?(Hash)
              item[access]
            else
              item.send(access)
            end
          item = item[index] if index
        end
      end
      setup_viewport
      render json: to_hash(item)
    end

    def new
      parser_options = self.parser_options.dup
      if klass.is_a?(Class) && klass < FieldsInspection
        parser_options[:inspect_fields] = Account.current.nil? || !::User.super_access?
      end
      if klass.is_a?(Class) && klass < Setup::AsynchronousPersistence::Model
        execution = Setup::AsynchronousPersistence.process(
          parser_options: parser_options,
          data_type_id: klass.data_type.id,
          access_scope: @oauth_scope&.to_s,
          data: request_data
        )
        render json: execution.to_hash(include_id: true, include_blanks: false), status: :accepted
      else
        parser = Parser.new(klass.data_type)
        parser_options[:create_callback] = -> model {
          fail Abort unless authorize_action(action: :create, klass: model)
        }
        parser_options[:update_callback] = -> record {
          fail Abort unless authorize_action(action: :update, item: record)
        }
        record = parser.create_from(request_data, parser_options)
        if record.errors.blank?
          if setup_viewport(:headers)
            render json: to_hash(record)
          else
            render body: nil
          end
        else
          render json: klass.pretty_errors(record), status: :unprocessable_entity
        end
      end
    rescue Abort
      # Aborted!
    end

    def update
      parser_options = self.parser_options.dup
      parser_options[:add_only] = true
      async = klass.is_a?(Class) && klass < Setup::AsynchronousPersistence::Model
      if async
        execution = Setup::AsynchronousPersistence.process(
          parser_options: parser_options,
          data_type_id: klass.data_type.id,
          record_id: @item.id,
          access_scope: @oauth_scope&.to_s,
          data: request_data,
          inspect_fields: Account.current.nil? || !::User.super_access?
        )
        render json: execution.to_hash(include_id: true, include_blanks: false), status: :accepted
      else
        @item.fill_from(request_data, parser_options)
        save_options = {}
        if @item.class.is_a?(Class) && @item.class < FieldsInspection
          save_options[:inspect_fields] = Account.current.nil? || !::User.super_access?
        end
        if Cenit::Utility.save(@item, save_options)
          if setup_viewport(:headers)
            render json: to_hash(@item)
          else
            render body: nil
          end
        else
          render json: klass.pretty_errors(@item), status: :unprocessable_entity
        end
      end
    end

    def destroy
      if @item.destroy
        render body: nil
      else
        render json: klass.pretty_errors(@item), status: :unprocessable_entity
      end
    end

    USER_MODEL_FIELDS = %w(name email password)
    USER_API_FIELDS = USER_MODEL_FIELDS + %w(token code)

    def new_user
      data = (JSON.parse(request_data) rescue {}).keep_if { |key, _| USER_API_FIELDS.include?(key) }
      data = data.with_indifferent_access
      data.reverse_merge!(email: params[:email], password: pwd = params[:password])
      data.reject! { |_, value| value.nil? }
      status = :not_acceptable
      response =
        if (token = data[:token] || params[:token])
          if (captcha_token = CaptchaToken.where(token: token).first)
            if (code = data[:code] || params[:code])
              if code == captcha_token.code
                token_data = captcha_token.data || {}
                if !data.key?(:email) || data[:email] == token_data[:email]
                  data.merge!(captcha_token.data || {}) { |_, left, right| left || right }
                  captcha_token.destroy
                  _, status, response = create_user_with(data)
                  response
                else #email mismatch
                  { email: ['does not match the one previously requested'] }
                end
              else #invalid code
                { code: ['is not valid'] }
              end
            else #code missing
              { code: ['is missing'] }
            end
          else #invalid token
            { token: ['is not valid'] }
          end
        elsif data[:email]
          data[:password] = Devise.friendly_token unless data[:password]
          if (user = User.new(data)).valid?(context: :create)
            if (captcha_token = CaptchaToken.create(email: data[:email], data: data)).errors.blank?
              status = :ok
              { token: captcha_token.token }
            else
              captcha_token.errors.to_json
            end
          else
            user.errors.to_json
          end
        else #bad request
          status = :bad_request
          { token: ['is missing'], email: ['is missing'] }
        end
      render json: response, status: status
    end

    def digest
      request.body.rewind
      options =
        begin
          JSON.parse(request.headers['X-Digest-Options'])
        rescue
          nil
        end
      options = {} unless options.is_a?(Hash)
      path = (params[:_digest_path] || '').split('/').map(&:presence).compact.join('_').presence
      path = path ? "digest_#{path}" : :digest
      no_logic = false
      if @item.respond_to?(method = "#{request.method.to_s.downcase}_#{path}") || @item.respond_to?(method = path)
        render @item.send(method, request, options)
      elsif @item.respond_to?(method = "handle_#{request.method.to_s.downcase}_#{path}")
        @item.send(method, self)
      elsif @item.is_a?(Setup::CenitDataType)
        model = @item.build_in.model
        if model.respond_to?(method = "#{request.method.to_s.downcase}_#{path}") || model.respond_to?(method = path)
          render model.send(method, request, options)
        elsif model.respond_to?(method = "handle_#{request.method.to_s.downcase}_#{path}")
          @item.send(method, self)
        else
          no_logic = true
        end
      else
        no_logic = true
      end
      if no_logic
        render json: {
          error: "No processable logic defined by #{@item.orm_model.data_type.custom_title}"
        }, status: :not_acceptable
      end
    end

    attr_reader :model

    def setup_request(options = {})
      if (@klass = options[:klass])
        @ns_name = @klass.data_type.namespace
      else
        @ns_name = nil
      end
      @ns_slug = options[:namespace] || params[:__ns_]
      @model = options[:model] || params[:__model_]
      @_id = options[:id] || params[:__id_]
      @format = options[:format] || params[:format]
      @path = options[:path] || "#{params[:path]}.#{params[:format]}" if params[:path] && params[:format]
      query_selector(options[:selector])
    end

    def find_item
      if (id = @_id) == 'me' && klass == User
        id = User.current_id
      elsif id == 'current' && klass == Account
        id = Account.current_id
      end
      if (@item = accessible_records.where(id: id).first)
        @item
      else
        render json: { status: 'item not found' }, status: :not_found
        false
      end
    end

    PARSER_OPTIONS = %w(add_only primary_field ignore reset update skip_refs_binding add_new).collect(&:to_sym)

    def parser_options
      @parser_options ||=
        begin
          unless (opts = Cenit::Utility.json_value_of(request.headers['X-Parser-Options'])).is_a?(Hash)
            opts = {}
          end
          PARSER_OPTIONS.each do |opt|
            next unless params.key?(opt)
            opts[opt] = Cenit::Utility.json_value_of(params[opt])
          end
          %w(primary_field primary_fields ignore reset update).each do |option|
            unless (value = opts.delete(option)).is_a?(Array)
              value = value.to_s.split(',').collect(&:strip)
            end
            opts[option] = value
          end
          opts
        end
    end

    def template_options
      @template_options ||=
        begin
          unless (opts = Cenit::Utility.json_value_of(request.headers['X-Template-Options'])).is_a?(Hash)
            opts = {}
          end
          opts = opts.with_indifferent_access
          if query_selector.present? && klass
            %w(only ignore embedding).each do |option|
              if query_selector.key?(option) && !klass.property?(option)
                unless (value = query_selector.delete(option)).is_a?(Array)
                  value = value.to_s.split(',').collect(&:strip)
                end
                opts[option] = value
              end
            end
          end
          if (fields_option = query_selector.delete(:fields)) || !opts.key?(:only)
            fields_option =
              case fields_option
                when Array
                  fields_option
                when Hash
                  fields_option.collect { |field, presence| presence.to_b ? field : nil }.select(&:presence)
                else
                  fields_option.to_s.split(',').collect(&:strip)
              end
            opts[:only] = fields_option
          end
          opts
        end
    end

    def setup_viewport(source = nil)
      unless source == :headers || template_options.key?(:viewport) || request_data.blank?
        template_options[:viewport] = request_data
      end
      unless template_options[:viewport] || template_options.key?(:include_id)
        template_options[:include_id] = true
      end
      template_options.key?(:viewport)
    end

    def query_options
      @query_options ||=
        if (opts = Cenit::Utility.json_value_of(request.headers['X-Query-Options'])).is_a?(Hash)
          opts
        else
          {}
        end.with_indifferent_access
    end

    def query_selector(selector = nil)
      parse_query_params =
        if selector
          @criteria = nil
        else
          selector = request.headers['X-Query-Selector']
          true
        end
      @criteria ||=
        begin
          unless (selector = Cenit::Utility.json_value_of(selector)).is_a?(Hash)
            selector = {}
          end
          selector = selector.with_indifferent_access
          if parse_query_params
            selector.merge!(
              params.permit!.reject do |key, _|
                %w(controller action __ns_ __model_ __id_ format api _digest_path).include?(key)
              end
            )
          end
          %w(page limit).each do |key|
            next unless selector.key?(key) && klass && !klass.property?(key)
            query_options[key] = selector.delete(key)
          end
          selector
        end
    end

    def create_user_with(data)
      status = :not_acceptable
      data[:password] ||= Devise.friendly_token
      data.reject! { |key, _| USER_MODEL_FIELDS.exclude?(key) }
      current_account = Account.current
      begin
        Account.current = nil
        (user = ::User.new(data)).save
      rescue
        user #TODO Handle sending confirmation email error
      ensure
        Account.current = current_account
      end
      response =
        if user.errors.blank?
          status = :ok
          { id: user.id.to_s, number: user.number, token: user.authentication_token }
        else
          user.errors.to_json
        end
      [user, status, response]
    end

    def get_limit
      @limit ||=
        begin
          limit_option = query_options.delete(:limit)
          limit = (query_selector.delete(:limit) || limit_option || Kaminari.config.default_per_page).to_i
          if limit.negative?
            Kaminari.config.default_per_page
          else
            [Kaminari.config.default_per_page, limit].min
          end
        end
    end

    def get_page
      @page ||=
        if (page = query_options.delete(:page))
          page.to_i
        else
          1
        end
    end

    def select_items
      asc = true
      if (order = query_selector.delete(:order))
        order.strip!
        asc = !order.match(/^-.*/)
      end

      limit = get_limit
      page = get_page
      skip = page < 1 ? 0 : (page - 1) * limit

      items = accessible_records.limit(limit).skip(skip).where(query_selector)

      if (sort = query_options[:sort])
        sort.each do |field, sort_option|
          items =
            case sort_option
              when 1
                items.asc(field)
              when -1
                items.desc(field)
              else
                items
            end
        end
      end
      if order
        if asc
          items.ascending(*order.split(','))
        else
          items.descending(*order.slice(1..-1).split(','))
        end
      else
        items
      end
    end

    def to_hash(item)
      Template.with(item) { |template| template.to_hash(template_options) }
    end

    def authorize_action(options = {})
      action = options[:action] || @_action_name
      success = true
      if klass
        action_symbol =
          case action
            when 'index', 'show'
              :read
            when 'new'
              :create
            else
              action.to_sym
          end
        if @ability.can?(action_symbol, options[:item] || options[:klass] || @item || klass) &&
          (@oauth_scope.nil? || @oauth_scope.can?(action_symbol, options[:klass] || klass))
          @access_token.hit if @access_token
        else
          success = false
          unless options[:skip_response]
            error_description = 'The requested action is out of the access token scope'
            response.headers['WWW-Authenticate'] = %(Bearer realm="example",error="insufficient_scope",error_description=#{error_description})
            render json: { error: 'insufficient_scope', error_description: error_description }, status: :forbidden
          end
        end
      else
        success = false
        unless options[:skip_response]
          if Account.current
            render json: { error: 'no model found' }, status: :not_found
          else
            error_description = 'The requested action is out of the access token scope'
            response.headers['WWW-Authenticate'] = %(Bearer realm="example",error="insufficient_scope",error_description=#{error_description})
            render json: { error: 'insufficient_scope', error_description: error_description }, status: :forbidden
          end
        end
      end
      success
    end

    protected

    def authorized_action?
      authorize_action(skip_response: true)
    end

    def exception_handler(exception)
      responder = Cenit::Responder.new(@request_id, exception)
      render json: responder, root: false, status: responder.code
      false
    end

    def find_model
      if klass
        true
      else
        render json: { status: 'model not found' }, status: :not_found
        false
      end
    end

    def get_data_type_by_slug(slug)
      if slug
        @data_types[slug] ||=
          begin
            build_in = nil
            if @ns_slug == 'setup' || @ns_slug == 'cenit'
              build_in_name =
                if slug == 'trace'
                  Mongoid::Tracer::Trace.to_s
                else
                  "#{@ns_slug.camelize}::#{slug.camelize}"
                end
              build_in =
                Setup::BuildInDataType[build_in_name] ||
                  Setup::BuildInDataType[slug.camelize] ||
                  Setup::BuildInFileType[build_in_name]
            end
            build_in ||
              begin
                if @ns_name.nil?
                  ns = Setup::Namespace.where(slug: @ns_slug).first
                  @ns_name = ns&.name || ''
                end
                if @ns_name
                  Setup::DataType.where(namespace: @ns_name, slug: slug).first ||
                    Setup::DataType.where(namespace: @ns_name, slug: slug.singularize).first ||
                    Setup::DataType.where(namespace: @ns_name.camelize, name: slug.camelize).first
                else
                  nil
                end
              end
          end
      else
        nil
      end
    end

    def get_data_type(root)
      get_data_type_by_slug(root) if root
    end

    def get_model(root)
      if (data_type = get_data_type(root))
        data_type.records_model
      else
        nil
      end
    end

    def klass
      @klass ||= get_model(model)
    end

    def accessible_records
      (@ability && klass.accessible_by(@ability, :read)) || klass.all
    end

    def save_request_data
      @data_types ||= {}
      @request_id = request.uuid
      @request_data = request.body.read
      setup_request
    end

    private

    attr_reader :request_data

    class Parser
      include Setup::DataTypeParser

      def initialize(data_type)
        @data_type = data_type
      end

      def parser_data_type
        @data_type
      end

      def method_missing(symbol, *args, &block)
        parser_data_type.send(symbol, *args, &block)
      end
    end

    class Template
      class << self
        include Edi::Formatter

        def with(record)
          Thread.current[SELF_RECORD_KEY] = record
          yield self
        ensure
          Thread.current[SELF_RECORD_KEY] = nil
        end

        def self_record
          Thread.current[SELF_RECORD_KEY]
        end

      end

      SELF_RECORD_KEY = "[cenit]#{self}.self_record"
    end

    class Abort < Exception; end
  end
end

module Cenit
  App.module_eval do

    def post_digest_config(request, _options = {})
      self.configuration = request.body.read
      if save
        {
          body: nil
        }
      else
        {
          json: self.class.pretty_errors(self),
          status: :unprocessable_entity
        }
      end
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  BuildInApp.module_eval do

    def get_digest_reinstall(_request, _options = {})
      if User.current_super_admin?
        execution = ::Setup::BuildInAppReinstall.process(
          build_in_app_id: id,
          task_description: "Re-installing build-in app #{app_module_name}"
        )
        if execution.is_a?(Setup::SystemNotification)
          fail execution.message
        end
        {
          json: execution.to_hash(include_id: true, include_blanks: false)
        }
      else
        {
          json: { '$': 'Not authorized' },
          status: :unauthorized
        }
      end
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  ApplicationId.class_eval do

    def get_digest_switch_trust(_request, options = {})
      self.trusted = !trusted
      if save
        {
          json: to_hash(options)
        }
      else
        {
          json: self.class.pretty_errors(self),
          status: :unprocessable_entity
        }
      end
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  ActiveTenant.class_eval do
    class << self

      def get_digest_clean(_request, _options = {})
        clean_all
        {
          body: nil
        }
      rescue
        {
          json: { '$': [$!.message] },
          status: :unprocessable_entity
        }
      end

      def get_digest_list(_request, _options = {})
        hash = to_hash
        active_tenants = ::Account.where(:id.in => hash.keys).to_a.map do |tenant|
          {
            tenant: {
              _reference: true,
              id: tenant.id.to_s,
              name: tenant.name
            },
            tasks: hash[tenant.id.to_s]
          }
        end
        {
          json: active_tenants
        }
      rescue
        {
          json: { '$': [$!.message] },
          status: :unprocessable_entity
        }
      end
    end
  end

  OauthAccessGrant.class_eval do

    def get_digest_tokens(_request, _options = {})
      {
        json: tokens.map do |token|
          {
            id: token.id.to_s,
            token: token.token,
            expires_at: token.expires_at,
            note: token.data && token.data[:note]
          }
        end
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end

    def post_digest_token(request, _options = {})
      error_field = '$'
      body = request.body.read
      payload =
        if body.blank?
          {}
        else
          JSON.parse(body)
        end.with_indifferent_access
      token_span = payload[:token_span]
      note = payload[:note]
      error_field = 'token_span'
      fail 'Expected to be a number' unless token_span && token_span.is_a?(Numeric)
      fail 'Expected to be in the future' unless token_span >= 0
      error_field = 'note'
      fail 'Expected to be a string' unless note && note.is_a?(String)
      fail 'Is too long' if note.length > 255
      {
        json: Cenit::OauthAccessToken.for(
          application_id,
          scope,
          ::User.current,
          token_span: token_span,
          note: note
        )
      }
    rescue
      {
        json: { error_field => [$!.message] },
        status: :unprocessable_entity
      }
    end

    def delete_digest_token(request, _options = {})
      token = OauthAccessToken.where(id: request.params[:id], token: request.params[:token]).first
      if token
        if token.destroy
          {
            body: nil
          }
        else
          {
            json: OauthAccessToken.pretty_errors(token),
            status: :unprocessable_entity
          }
        end
      else
        {
          body: nil, status: :not_found
        }
      end
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end
end

module Setup
  DataType.class_eval do

    def handle_get_digest(controller)
      if (id = controller.request.headers['X-Record-Id'])
        controller.setup_request(namespace: ns_slug, klass: records_model, id: id)
        controller.show if (item = controller.find_item) && controller.authorize_action(
          action: :read,
          item: item,
          klass: records_model
        )
      else
        controller.setup_request(namespace: ns_slug, klass: records_model)
        controller.index if controller.authorize_action(
          action: :read,
          klass: records_model
        )
      end
    end

    def handle_get_digest_search(controller)
      request_selector = controller.query_selector
      query = request_selector.delete('query')
      search_selector = records_model.search_selector(query)
      unless request_selector.empty?
        search_selector = { '$and' => [request_selector, search_selector] }
      end
      controller.setup_request(
        namespace: ns_slug,
        klass: records_model,
        selector: search_selector
      )
      controller.index if controller.authorize_action(
        action: :read,
        klass: records_model
      )
    end

    def handle_post_digest(controller)
      controller.setup_request(namespace: ns_slug, klass: records_model)
      controller.new
    end

    def handle_delete_digest(controller)
      query = where(controller.query_selector)
      response =
        if query.count == 1
          item = query.first
          if controller.authorize_action(action: :delete, item: item, klass: records_model)
            if item.destroy
              { body: nil }
            else
              {
                json: records_model.pretty_errors(item),
                status: :unprocessable_entity
              }
            end
          end
        elsif controller.authorize_action(action: :delete, klass: records_model)
          execution = Deletion.process(
            data_type_id: id,
            selector: controller.query_selector.to_json,
            task_description: "Deleting #{name.to_title.pluralize}"
          )
          {
            json: controller.to_hash(execution),
            status: :accepted
          }
        end
      controller.render response if response
    end

    def digest_schema(request, options = {})
      data =
        if request.get?
          merged_schema(options)
        else
          merge_schema(JSON.parse(request.body.read), options)
        end
      {
        json: data
      }
    rescue Exception => ex
      {
        json: { error: ex.message },
        status: :bad_request
      }
    end

    def get_digest_origins(_request, _options = {})
      model = records_model
      origins =
        if (model.is_a?(Class) && model < CrossOrigin::Document) || model == Collection
          origins = model.origins
                      .map(&:to_sym)
                      .select { |origin| Crossing.authorized_crossing_origins.include?(origin) }
                      .map { |a| [a, a] }.to_h
          unless User.current_cross_shared?
            origins.delete(:shared)
          end
          origins.keys
        else
          [:default]
        end
      {
        body: origins.map(&:to_s)
      }
    rescue
      {
        json: { error: $!.message },
        status: :bad_request
      }
    end

    def post_digest_cross(request, _options = {})
      fail 'Unable to cross' unless model.is_a?(Class) && (
        model < CrossOrigin::Document ||
        model == Collection
      )
      options = JSON.parse(request.body.read)
      execution = Setup::Crossing.process(
        data_type_id: id,
        selector: options['selector'].to_json,
        origin: options['origin'],
        task_description: "Crossing #{name.to_title.pluralize}"
        #TODO Cross dependencies option
        )
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end

    def post_digest_pull_import(request, options = {})
      readable =
        if request.content_type.downcase == 'multipart/form-data'
          request.params[:data] || request.params[:file] || fail('Missing data (or file) part')
        else
          request.body
        end
      readable.rewind
      data =
        begin
          JSON.parse(readable.read)
        rescue
          fail 'Invalid JSON data'
        end
      data = [data] if data.is_a?(Hash)
      model = records_model
      if model == Setup::Collection
        if data.length == 1
          data = data[0]
        else
          fail 'Array data is not allowed for pulling collections'
        end
      else
        collecting_property = Setup::CrossSharedCollection::COLLECTING_PROPERTIES.detect { |name| Setup::CrossSharedCollection.reflect_on_association(name).klass >= model }
        data = { collecting_property => data }.with_indifferent_access
      end
      execution = Setup::PullImport.process(
        data: data.to_json,
        discard_collection: model != Setup::Collection,
        task_description: options['task_description']
      )
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { error: $!.message },
        status: :bad_request
      }
    end
  end

  [FileDataType, JsonDataType].each do |k|
    k.class_eval do

      def get_digest_config(_request, _options = {})
        if (config = self.config).new_record?
          config = {}
        else
          config = config.to_hash
        end
        {
          json: config
        }
      rescue
        {
          json: { '$': [$!.message] },
          status: :unprocessable_entity
        }
      end

      def post_digest_config(request, _options = {})
        hash = JSON.parse(request.body.read)
        config.slug = hash['slug']
        config.trace_on_default = hash['trace_on_default']
        config.save!
        {
          json: config.to_hash(include_id: true)
        }
      rescue
        {
          json: { '$': [$!.message] },
          status: :unprocessable_entity
        }
      end
    end
  end

  [PullImport, SharedCollectionPull, ApiPull].each do |pull_model|
    pull_model.class_eval do

      def post_digest_pull(request, _options = {})
        options = JSON.parse(request.body.read)
        message[:install] = options['install'].to_b if ask_for_install?
        unless (pull_parameters = options['pull_parameters']).is_a?(Hash)
          pull_parameters = {}
        end
        message[:pull_parameters] = pull_parameters
        execution = self.retry
        if execution.is_a?(Setup::SystemNotification)
          fail execution.message
        end
        {
          json: execution.to_hash(include_id: true, include_blanks: false),
          status: :accepted
        }
      rescue
        {
          json: { error: $!.message },
          status: :bad_request
        }
      end
    end
  end

  FileDataType.class_eval do

    def post_digest_upload(request, options = {})
      readable =
        if request.content_type.downcase == 'multipart/form-data'
          request.params[:data] || request.params[:file] || fail('Missing data (or file) part')
        else
          request.body
        end
      readable.rewind
      file = create_from(readable, options)
      if file.errors.present?
        {
          json: records_model.pretty_errors(file),
          status: :unprocessable_entity
        }
      else
        {
          json: Api::V3::ApiController::Template.with(file) do |template|
            template.to_hash(only: %w(id filename contentType length md5 public_url))
          end
        }
      end
    rescue Exception => ex
      {
        json: { error: ex.message },
        status: :bad_request
      }
    end

    def handle_get_digest_download(controller)
      file = where(controller.query_selector).first
      if file
        controller.send_data(file.data, filename: file.filename, type: file.contentType)
      else
        controller.render body: nil, status: :not_found
      end
    rescue
      controller.render json: { error: $!.message }, status: :bad_request
    end
  end

  Flow.class_eval do

    def post_digest(request, _options = {})
      begin
        message = JSON.parse(request.body.read)
        fail unless message.is_a?(Hash)
      rescue
        message = {}
      end
      if (selector = message['selector'])
        message['selector'] = selector.to_json
      end
      begin
        execution = process(message.with_indifferent_access)
        if execution.is_a?(Setup::SystemNotification)
          fail execution.message
        end
        execution.reload
        {
          json: execution.to_hash(include_id: true, include_blanks: false)
        }
      rescue
        {
          json: { error: $!.message },
          status: :bad_request
        }
      end
    end
  end

  Algorithm.class_eval do

    def post_digest(request, _options = {})
      hash = input = JSON.parse(request.body.read)
      if input.is_a?(Array)
        hash = parameters.map { |p, index| [p.name, input[index]] }
      else
        input = parameters.map { |p| hash[p.name] }
      end
      Mongoff::Validator.validate_instance(
        hash,
        schema: configuration_schema,
        data_type: self.class.data_type
      )
      execution = run_asynchronous(input)
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      execution.reload
      {
        json: execution.to_hash(include_id: true, include_blanks: false)
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  Template.class_eval do

    def post_digest(request, _options = {})
      options = JSON.parse(request.body.read)
      execution = Setup::Translation.process(
        translator_id: id,
        data_type_id: (
          options['source_data_type_id'] ||
            options['data_type_id'] ||
              ((data_type = options['data_type']) && data_type['id']) ||
                source_data_type_id
        ),
        selector: options['selector'].to_json,
        skip_notification_level: true,
        #options: @form_object.options TODO Template options
      )
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  ParserTransformation.class_eval do

    def post_digest(request, options = {})
      readable =
        if request.content_type.downcase == 'multipart/form-data'
          request.params[:data] || request.params[:file] || fail('Missing data (or file) part')
        else
          request.body
        end
      readable.rewind
      msg = {
        translator_id: id,
        data_type_id: (
          options['target_data_type_id'] ||
            options['data_type_id'] ||
              ((data_type = options['data_type']) && data_type['id']) ||
                target_data_type_id
        ),
        #decompress_content: decompress, TODO Parser options
        data: BSON::Binary.new(readable.read),
        #options: @form_object.options
      }
      execution = Setup::DataImport.process(msg)
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  UpdaterTransformation.class_eval do

    def post_digest(request, _options = {})
      options = JSON.parse(request.body.read)
      execution = Setup::Translation.process(
        translator_id: id,
        data_type_id: (
          options['target_data_type_id'] ||
            options['data_type_id'] ||
              ((data_type = options['data_type']) && data_type['id']) ||
                target_data_type_id
        ),
        selector: options['selector'].to_json,
        skip_notification_level: true,
        #options: @form_object.options TODO Updater options
        )
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  ConverterTransformation.class_eval do

    def post_digest(request, _options = {})
      options = JSON.parse(request.body.read)
      execution = Setup::Translation.process(
        translator_id: id,
        data_type_id: (
        options['target_data_type_id'] ||
          options['data_type_id'] ||
          ((data_type = options['data_type']) && data_type['id']) ||
          target_data_type_id
        ),
        selector: options['selector'].to_json,
        skip_notification_level: true,
      #options: @form_object.options TODO Convert options
        )
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  Collection.class_eval do

    def post_digest_share(request, _options = {})
      # TODO Validate pull parameters
      execution = Setup::CollectionSharing.process(
        collection_id: id,
        data: request.body.read,
        task_description: "Sharing collection #{name}"
      )
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end

    def delete_digest_shred(_request, _options = {})
      execution = Setup::CollectionShredding.process(
        collection_id: id,
        task_description: "Shredding collection #{name}"
      )
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end

    def post_digest_push(request, _options = {})
      options = JSON.parse(request.body.read)
      execution = Setup::Push.process(
        source_collection_id: id,
        shared_collection_id: (
          options['shared_collection_id'] ||
            ((shared_collection = options['shared_collection']) && shared_collection['id'])
        ),
        task_description: "Pushing #{name}"
      )
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  CrossSharedCollection.class_eval do

    def get_digest_reinstall(_request, _options = {})
      execution = SharedCollectionReinstall.process(
        shared_collection_id: id,
        task_description: "Re-installing #{name}"
      )
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false)
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  [CrossSharedCollection, ApiSpec].each do |model|
    model.class_eval do

      def post_digest_pull(request, _options)
        data = JSON.parse(request.body.read)
        execution = pull(
          pull_parameters: data['pull_parameters'] || {}
        )
        if execution.is_a?(Setup::SystemNotification)
          fail execution.message
        end
        {
          json: execution.to_hash(include_id: true, include_blanks: false),
          status: :accepted
        }
      rescue
        {
          json: { '$': [$!.message] },
          status: :unprocessable_entity
        }
      end
    end
  end

  Task.class_eval do

    def get_digest_retry(_request, _options = {})
      if (execution = self.retry)
        if execution.is_a?(Setup::SystemNotification)
          fail execution.message
        end
        {
          json: execution.to_hash(include_id: true, include_blanks: false)
        }
      else
        fail "Can't retry at this moment"
      end
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end

    def post_digest_schedule(request, _options = {})
      sch_data = request.body.read.strip
      sch_data = sch_data.empty? ? {} : JSON.parse(sch_data)
      scheduler =
        if sch_data.empty?
          nil
        else
          Setup::Scheduler.create_from_json!(sch_data)
        end
      execution = schedule(scheduler, :exception)
      unless execution
        fail "Can't #{scheduler ? 're-' : 'un'}schedule right now, the task is #{status}"
      end
      if execution.is_a?(Setup::SystemNotification)
        fail execution.message
      end
      {
        json: execution.to_hash(include_id: true, include_blanks: false),
        status: :accepted
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  Application.class_eval do

    def get_digest_access(_request, options = {})
      access_grant = ::Cenit::OauthAccessGrant.where(
        application_id_id: application_id_id
      ).first
      if access_grant
        {
          json: access_grant.to_hash(options)
        }
      else
        {
          body: nil,
          status: :not_found
        }
      end
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end

    def post_digest_access(request, options = {})
      scope = ::Cenit::OauthScope.new(JSON.parse(request.body.read)['scope'])
      fail 'Is not valid' unless scope.valid?
      access_grant = ::Cenit::OauthAccessGrant.where(
        application_id_id: application_id_id
      ).first
      if access_grant
        access_grant.scope = scope.to_s
      else
        access_grant = ::Cenit::OauthAccessGrant.new(
          application_id_id: application_id_id,
          scope: scope.to_s
        )
      end
      access_grant.save!
      {
        json: access_grant.to_hash(options)
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end

    def get_digest_registration(_request, _options = {})
      {
        json: {
          slug: application_id.slug.presence,
          oauth_name: application_id.oauth_name.presence
        }
      }
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end

    def post_digest_registration(request, options = {})
      data = JSON.parse(request.body.read).with_indifferent_access
      app_id = application_id
      if app_id.regist_with(data).valid? && app_id.save
        {
          json: app_id.to_hash(options)
        }
      else
        {
          json: ::Cenit::ApplicationId.pretty_errors(app_id),
          status: :unprocessable_entity
        }
      end
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end

  EmailNotification.class_eval do

    def self.get_digest_email_data_type(_request, _options = {})
      if (data_type = Setup::Configuration.singleton_record.email_data_type)
        {
          json: {
            id: data_type.id.to_s,
            namespace: data_type.namespace,
            name: data_type.name
          }
        }
      else
        {
          body: nil
        }
      end
    rescue
      {
        json: { '$': [$!.message] },
        status: :unprocessable_entity
      }
    end
  end
end

require 'mongoff/grid_fs/file'

module Mongoff
  module GridFs
    File.class_eval do

      def post_digest(request, options = {})
        fill_from(options)
        self.data = request.body
        save
        {
          json: Api::V3::ApiController::Template.with(self) { |template| template.to_hash }
        }
      rescue Exception => ex
        {
          json: { error: ex.message },
          status: :bad_request
        }
      end

      def handle_get_digest(controller)
        controller.send_data(data, filename: filename, type: contentType)
      end
    end
  end
end

{
  get: {
    cancel: Cancelable,
    switch: Switchable
  }
}.each do |method, actions|
  actions.each do |action, mod|
    mod.module_eval <<-RUBY
      def #{method}_digest_#{action}(_request, options = {})
        #{action}
        {
          json: to_hash(options)
        }
      rescue
        {
          json: { error: $!.message },
          status: :bad_request
        }
      end
    
      ClassMethods.module_eval do
        def #{method}_digest_#{action}(_request, options = {})
          #{action}_all(where(options['selector'] || {}))
          {
            body: nil
          }
        rescue
          {
            json: { error: $!.message },
            status: :bad_request
          }
        end
      end
    RUBY
  end
end

::Account.class_eval do

  def delete_digest_shred(_request, _options = {})
    clean_up
    {
      body: nil
    }
  rescue
    {
      json: { '$': [$!.message] },
      status: :unprocessable_entity
    }
  end
end

::Script.class_eval do

  def post_digest(request, _options = {})
    hash = input = JSON.parse(request.body.read)
    if input.is_a?(Array)
      hash = parameters.map { |p, index| [p.name, input[index]] }
    else
      input = parameters.map { |p| hash[p.name] }
    end
    # TODO Validates input hash
    execution = ::ScriptExecution.process(
      script_id: id,
      input: input,
      skip_notification_level: true
    )
    if execution.is_a?(Setup::SystemNotification)
      fail execution.message
    end
    {
      json: execution.to_hash(include_id: true, include_blanks: false),
      status: :accepted
    }
  rescue
    {
      json: { '$': [$!.message] },
      status: :unprocessable_entity
    }
  end
end

::User.class_eval do
  def get_digest_switch_sudo(_request, options = {})
    if has_role?(:super_admin)
      if update(super_admin_enabled: !super_admin_enabled)
        {
          json: to_hash(options)
        }
      else
        {
          json: self.class.pretty_errors(self),
          status: :unprocessable_entity
        }
      end
    else
      {
        json: { '$': 'Not super user' },
        status: :unauthorized
      }
    end
  rescue
    {
      json: { '$': [$!.message] },
      status: :unprocessable_entity
    }
  end
end
