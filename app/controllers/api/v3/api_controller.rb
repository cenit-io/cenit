module Api::V3
  class ApiController < ApplicationController

    before_action :allow_origin_header
    before_action :authorize_account, except: [:new_user, :cors_check]
    before_action :save_request_data
    before_action :find_model, except: [:new_user, :cors_check]
    before_action :find_item, only: [:update, :show, :destroy, :digest]
    before_action :authorize_action, except: [:new_user, :cors_check]

    rescue_from Exception, with: :exception_handler

    respond_to :json

    def cors_check
      cors_headers
      render body: nil
    end

    def allow_origin_header
      headers['Access-Control-Allow-Origin'] = request.headers['Origin'] || ::Cenit.homepage
    end

    def cors_headers
      allow_origin_header
      headers['Access-Control-Allow-Credentials'] = 'false'
      headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Accept, Content-Type, Authorization, X-Template-Options, X-Query-Options, X-Query-Selector, X-Digest-Options, X-Parser-Options, X-JSON-Path, X-Record-Id'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
      headers['Access-Control-Max-Age'] = '1728000'
    end

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
      if klass.is_a?(Class) && klass < FieldsInspection
        parser_options[:inspect_fields] = Account.current.nil? || !::User.current_super_admin?
      end
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
    rescue Abort
      # Aborted!
    end

    def update
      parser_options[:add_only] = true
      @item.fill_from(request_data, parser_options)
      save_options = {}
      if @item.class.is_a?(Class) && @item.class < FieldsInspection
        save_options[:inspect_fields] = Account.current.nil? || !::User.current_super_admin?
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
      @klass = @ns_name = nil
      @ns_slug = options[:namespace] || params[:__ns_]
      @model = options[:model] || params[:__model_]
      @_id = options[:id] || params[:__id_]
      @format = options[:format] || params[:format]
      @path = options[:path] || "#{params[:path]}.#{params[:format]}" if params[:path] && params[:format]
      query_selector
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

    def query_selector
      @criteria ||=
        begin
          unless (selector = Cenit::Utility.json_value_of(request.headers['X-Query-Selector'])).is_a?(Hash)
            selector = {}
          end
          selector = selector.with_indifferent_access
          selector.merge!(params.permit!.reject { |key, _| %w(controller action __ns_ __model_ __id_ format api).include?(key) })
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

    def authorize_account
      Account.current = User.current = error_description = nil
      if (auth_header = request.headers['Authorization'])
        auth_header = auth_header.to_s.squeeze(' ').strip.split(' ')
        if auth_header.length == 2
          @access_token = access_token = Cenit::OauthAccessToken.where(token_type: auth_header[0], token: auth_header[1]).first
          if access_token&.alive?
            if (user = access_token.user)
              User.current = user
              if access_token.set_current_tenant!
                access_grant = Cenit::OauthAccessGrant.where(application_id: access_token.application_id).first
                if access_grant
                  @oauth_scope = access_grant.oauth_scope
                else
                  error_description = 'Access grant revoked or moved outside token tenant'
                end
              end
            else
              error_description = 'The token owner is no longer an active user'
            end
          else
            error_description = 'Access token is expired or malformed'
          end
        else
          error_description = 'Malformed authorization header'
        end
        if User.current && Account.current
          @ability = Ability.new(User.current)
          true
        else
          unless error_description
            report = Setup::SystemReport.create(message: "Unable to locate tenant for authorization header #{auth_header}")
            error_description = "Ask for support by supplying this code: #{report.id}"
          end
          response.headers['WWW-Authenticate'] = %(Bearer realm="example",error="invalid_token",error_description=#{error_description})
          render json: { error: 'invalid_token', error_description: error_description }, status: :unauthorized
          false
        end
      else
        @ability = Ability.new(nil)
        true
      end
    end

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
          if @ns_slug == 'setup' || @ns_slug == 'cenit'
            build_in_name =
              if slug == 'trace'
                Mongoid::Tracer::Trace.to_s
              else
                "#{@ns_slug.camelize}::#{slug.camelize}"
              end
            Setup::BuildInDataType[build_in_name] || Setup::BuildInDataType[slug.camelize]
          else
            if @ns_name.nil?
              ns = Setup::Namespace.where(slug: @ns_slug).first
              @ns_name = (ns && ns.name) || ''
            end
            if @ns_name
              Setup::DataType.where(namespace: @ns_name, slug: slug).first ||
                Setup::DataType.where(namespace: @ns_name, slug: slug.singularize).first ||
                Setup::DataType.where(namespace: @ns_name.camelize, name: slug.camelize).first
            else
              nil
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

module Setup
  DataType.class_eval do

    def handle_get_digest(controller)
      if (id = controller.request.headers['X-Record-Id'])
        controller.setup_request(namespace: ns_slug, model: slug, id: id)
        controller.show if (item = controller.find_item) && controller.authorize_action(
          action: :read,
          item: item,
          klass: records_model
        )
      else
        controller.setup_request(namespace: ns_slug, model: slug)
        controller.index if controller.authorize_action(
          action: :read,
          klass: records_model
        )
      end
    end

    def handle_post_digest(controller)
      controller.setup_request(namespace: ns_slug, model: slug)
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
          execution = Deletion.process(model_name: records_model.to_s, selector: query.selector)
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
      {
        json: Api::V3::ApiController::Template.with(file) { |template| template.to_hash }
      }
    rescue Exception => ex
      {
        json: { error: ex.message },
        status: :bad_request
      }
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
      execution = process(message.with_indifferent_access)
      execution.reload
      {
        json: execution.to_hash(include_id: true, include_blanks: false)
      }
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

  ParserTransformation.class_eval do

    def post_digest(request, options = {})
      msg = {
        translator_id: id,
        data_type_id: (
          options['target_data_type_id'] ||
            options['data_type_id'] ||
              ((data_type = options['data_type']) && data_type['id']) ||
                target_data_type_id
        ),
        #decompress_content: decompress, TODO Parser options
        data: request.body.read,
        #options: @form_object.options
      }
      execution = Setup::DataImport.process(msg)
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
  cancel: Cancelable,
  switch: Switchable
}.each do |action, mod|
  mod.module_eval <<-RUBY
  
  def digest_#{action}(_request, options = {})
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
    def digest_#{action}(_request, options = {})
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
