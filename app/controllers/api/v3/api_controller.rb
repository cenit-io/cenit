module Api::V3
  class ApiController < ApplicationController

    before_action :authorize_account, except: [:new_user, :cors_check]
    before_action :save_request_data, :allow_origin_header
    before_action :authorize_action, except: [:new_user, :push, :cors_check] #TODO Review push action
    before_action :find_item, only: [:update, :show, :destroy, :digest]

    rescue_from Exception, :with => :exception_handler

    respond_to :json

    def cors_check
      cors_headers
      render nothing: true
    end

    def allow_origin_header
      headers['Access-Control-Allow-Origin'] = request.headers['Origin'] || ::Cenit.homepage
    end

    def cors_headers
      allow_origin_header
      headers['Access-Control-Allow-Credentials'] = false
      headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Accept, Content-Type, Authorization, X-Template-Options, X-Query-Selector X-Digest-Options'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
      headers['Access-Control-Max-Age'] = '1728000'
    end

    def index
      page = get_page
      res =
        if klass
          @template_options.delete(:inspecting)
          if (model_ignore = klass.index_ignore_properties).present?
            @template_options[:ignore] =
              if (ignore_option = @template_options[:ignore])
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
          @template_options[:max_entries] =
            if (max_entries = @template_options[:max_entries])
              max_entries = max_entries.to_i
              if max_entries == 0 || max_entries > maximum_entries
                maximum_entries
              else
                max_entries
              end
            else
              maximum_entries
            end
          items = select_items
          items_data = items.map do |item|
            Template.with(item) do |template|
              template.default_hash(@template_options)
            end
          end
          count = items.count
          json = {
            current_page: page,
            count: count,
            items: items_data,
            data_type: {
              (@template_options[:raw_properties] ? :_id : :id) => klass.data_type.id.to_s
            }
          }
          if get_limit > 0
            json[:total_pages] = (count * 1.0 / get_limit).ceil
          end
          {
            json: json
          }
        else
          {
            json: { error: 'no model found' },
            status: :not_found
          }
        end
      render res
    end

    def show
      render json: Template.with(@item) { |template| template.to_hash(@template_options) }
    end

    def push
      response =
        {
          success: success_report = Hash.new { |h, k| h[k] = [] },
          errors: broken_report = Hash.new { |h, k| h[k] = [] }
        }
      @parser_options[:add_only] = true unless @parser_options.key?('add_only')
      @payload.each do |root, message|
        @model = root
        if authorized_action? && (data_type = @payload.data_type_for(root))
          parser = Parser.new(data_type)
          message = [message] unless message.is_a?(Array)
          message.each do |item|
            options = @parser_options.merge(create_collector: Set.new).symbolize_keys
            model = data_type.records_model
            if model.is_a?(Class) && model < FieldsInspection
              options[:inspect_fields] = Account.current.nil? || !::User.current_super_admin?
            end
            if (record = parser.send(@payload.create_method,
                                     @payload.process_item(item, data_type, options),
                                     options)).errors.blank?
              success_report[root.pluralize] << record.inspect_json(include_id: true, inspect_scope: options[:create_collector])
            else
              broken_report[root] << { errors: record.errors.full_messages, item: item }
            end
          end
        else
          broken_report[root] = 'no model found'
        end
      end
      response.delete(:success) if success_report.blank?
      response.delete(:errors) if broken_report.blank?
      render json: response, status: 202
    end

    def new
      response = {}
      %w(success warnings errors).each { |key| response[key.to_sym] = Hash.new { |h, k| h[k] = [] } }
      @payload.each do |root, message|
        if (data_type = @payload.data_type_for(root))
          parser = Parser.new(data_type)
          message = [message] unless message.is_a?(Array)
          message.each do |item|
            begin
              options = @parser_options.merge(create_collector: Set.new).symbolize_keys
              model = data_type.records_model
              if model.is_a?(Class) && model < FieldsInspection
                options[:inspect_fields] = Account.current.nil? || !::User.current_super_admin?
              end
              if (record = parser.send(@payload.create_method,
                                       @payload.process_item(item, data_type, options),
                                       options)).errors.blank?
                response[:success][root] << record.inspect_json(include_id: true, inspect_scope: options[:create_collector])
                if (warnings = record.try(:warnings))
                  warnings =
                    begin
                      warnings.to_json
                    rescue
                      nil
                    end
                  response[:warnings][root] << { record.id.to_s => JSON.parse(warnings) } if warnings
                end
              else
                response[:errors][root] << { errors: record.errors.full_messages, item: item }
              end
            rescue Exception => ex
              response[:errors][root] = { errors: ex.message, item: item }
            end
          end
        else
          response[:errors][root] = 'no model found'
        end
      end
      response.reject! { |_, v| v.blank? }
      render json: response
    end

    def update
      @payload.each do |_, message|
        message = message.first if message.is_a?(Array)
        @parser_options[:add_only] = true
        @item.send(@payload.update_method, message, @parser_options)
        save_options = {}
        if @item.class.is_a?(Class) && @item.class < FieldsInspection
          save_options[:inspect_fields] = Account.current.nil? || !::User.current_super_admin?
        end
        if Cenit::Utility.save(@item, save_options)
          if (warnings = @item.try(:warnings))
            warnings =
              begin
                warnings.to_json
              rescue
                nil
              end
            response.headers['X-Warnings'] = warnings if warnings
          end
          find_item
          render json: @item.to_hash, status: :ok
        else
          render json: { errors: @item.errors.full_messages }, status: :not_acceptable
        end
        break
      end
    end

    def destroy
      if @item.destroy
        render json: { status: :ok }
      else
        render json: { errors: @item.errors.full_messages }, status: :not_acceptable
      end
    end

    USER_MODEL_FIELDS = %w(name email password password_confirmation)
    USER_API_FIELDS = USER_MODEL_FIELDS + %w(token code)

    def new_user
      data = (JSON.parse(@webhook_body) rescue {}).keep_if { |key, _| USER_API_FIELDS.include?(key) }
      data = data.with_indifferent_access
      data.reverse_merge!(email: params[:email], password: pwd = params[:password], password_confirmation: params[:password_confirmation] || pwd)
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
          data[:password_confirmation] = data[:password] unless data[:password_confirmation]
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
      if @item.respond_to?(method = "#{request.method.to_s.downcase}_digest") || @item.respond_to?(method = :digest)
        options =
          begin
            JSON.parse(request.headers['X-Digest-Options'])
          rescue
            nil
          end
        options = {} unless options.is_a?(Hash)
        render @item.send(method, request, options)
      elsif @item.respond_to?(method = "handle_#{request.method.to_s.downcase}_digest")
        @item.send(method, self)
      else
        render json: {
          error: "No processable logic defined by #{@item.orm_model.data_type.custom_title}"
        }, status: :not_acceptable
      end
    end

    protected

    def create_user_with(data)
      status = :not_acceptable
      data[:password] ||= Devise.friendly_token
      data[:password_confirmation] ||= data[:password]
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
      unless @limit
        limit_option = @criteria_options.delete(:limit)
        limit = (@criteria.delete(:limit) || limit_option || Kaminari.config.default_per_page).to_i
        @limit =
          if limit < 0
            Kaminari.config.default_per_page
          else
            [Kaminari.config.default_per_page, limit].min
          end
      end
      @limit
    end

    def get_page
      @page ||=
        if (page = @criteria.delete(:page))
          page.to_i
        else
          1
        end
    end

    def select_items
      asc = true
      if (order = @criteria.delete(:order))
        order.strip!
        asc = !order.match(/^-.*/)
      end

      limit = get_limit
      page = get_page
      skip = page < 1 ? 0 : (page - 1) * limit

      # TODO: Include Kaminari methods on CrossOrigin::Criteria
      items = accessible_records.limit(limit).skip(skip).where(@criteria)

      if (sort = @criteria_options[:sort])
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

    def authorize_account
      user = nil
      if (auth_header = request.headers['Authorization'])
        auth_header = auth_header.to_s.squeeze(' ').strip.split(' ')
        if auth_header.length == 2
          access_token = Cenit::OauthAccessToken.where(token_type: auth_header[0], token: auth_header[1]).first
          if access_token && access_token.alive?
            if access_token.set_current_tenant!
              access_grant = Cenit::OauthAccessGrant.where(application_id: access_token.application_id).first
              if access_grant
                @oauth_scope = access_grant.oauth_scope
              end
            end
          end
        end
      else

        # New key and token params.
        key = request.headers['X-Tenant-Access-Key'] || params.delete('X-Tenant-Access-Key')
        token = request.headers['X-Tenant-Access-Token'] || params.delete('X-Tenant-Access-Token')

        # Legacy key and token params.
        key ||= request.headers['X-User-Access-Key'] || params.delete('X-User-Access-Key')
        token ||= request.headers['X-User-Access-Token'] || params.delete('X-User-Access-Token')

        if key || token
          [
            User,
            Account
          ].each do |model|
            next if user
            record = model.where(key: key).first
            if record && Devise.secure_compare(record[:authentication_token], token)
              Account.current = record.api_account
              user = record.user
            end
          end
        end
        unless key || token
          key = request.headers['X-Hub-Store']
          token = request.headers['X-Hub-Access-Token']
          Account.set_current_with_connection(key, token) if key || token
        end
      end
      if user
        User.current = user
      else
        User.current ||= (Account.current ? Account.current.owner : nil)
      end
      @ability = Ability.new(User.current)
      true
    end

    def authorized_action?
      authorize_action(skip_response: true)
    end

    def authorize_action(options = {})
      success = true
      if klass
        action_symbol =
          case @_action_name
          when 'push'
            get_data_type(@model).is_a?(Setup::FileDataType) ? :upload_file : :new
          when 'update'
            :edit
          when 'retry'
            :retry_task
          when 'digest'
            :show
          else
            @_action_name.to_sym
          end
        unless @ability.can?(action_symbol, @item || klass) &&
          (@oauth_scope.nil? || @oauth_scope.can?(action_symbol, klass))
          success = false
          unless options[:skip_response]
            responder = Cenit::Responder.new(@request_id, :unauthorized)
            render json: responder, root: false, status: responder.code
          end
        end
      else
        success = false
        unless options[:skip_response]
          if Account.current
            render json: { error: 'no model found' }, status: :not_found
          else
            render json: { error: 'not unauthorized' }, status: :unauthorized
          end
        end
      end
      success
    end

    def exception_handler(exception)
      responder = Cenit::Responder.new(@request_id, exception)
      render json: responder, root: false, status: responder.code
      false
    end

    def find_item
      if (id = params[:id]) == 'me' && klass == User
        id = User.current_id
      end
      if (@item = accessible_records.where(id: id).first)
        true
      else
        render json: { status: 'item not found' }, status: :not_found
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
                Setup::DataType.where(namespace: @ns_name, slug: slug.singularize).first
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
      @klass ||= get_model(@model)
    end

    def accessible_records
      (@ability && klass.accessible_by(@ability)) || klass.all
    end

    def save_request_data
      @data_types ||= {}
      @request_id = request.uuid
      @webhook_body = request.body.read
      @ns_slug = params[:ns]
      @ns_name = nil
      @model = params[:model]
      @format = params[:format]
      @path = "#{params[:path]}.#{params[:format]}" if params[:path] && params[:format]
      case @_action_name
      when 'new', 'push', 'update'
        unless (@parser_options = Cenit::Utility.json_value_of(request.headers['X-Parser-Options'])).is_a?(Hash)
          @parser_options = {}
        end
        params.each do |key, value|
          next if %w(controller action ns model format api).include?(key)
          @parser_options[key] = Cenit::Utility.json_value_of(value)
        end
        %w(primary_field primary_fields ignore reset).each do |option|
          unless (value = @parser_options.delete(option)).is_a?(Array)
            value = value.to_s.split(',').collect(&:strip)
          end
          @parser_options[option] = value
        end
        content_type = request.content_type
        if @_action_name == 'push' && %w(application/json application/xml).exclude?(content_type)
          content_type =
            begin
              JSON.parse(@webhook_body)
              'application/json'
            rescue Exception
              begin
                Nokogiri::XML(@webhook_body)
                'application/xml'
              rescue Exception
                nil
              end
            end
        end
        @payload =
          case content_type
          when 'application/json'
            JSONPayload
          when 'application/xml'
            XMLPayload
          else
            BasicPayload
          end.new(controller: self,
                  message: @webhook_body,
                  content_type: content_type)
      when 'index', 'show'
        unless (@criteria = Cenit::Utility.json_value_of(request.headers['X-Query-Selector'])).is_a?(Hash)
          @criteria = {}
        end
        unless (@criteria_options = Cenit::Utility.json_value_of(request.headers['X-Query-Options'])).is_a?(Hash)
          @criteria_options = {}
        end
        @criteria = @criteria.with_indifferent_access
        @criteria_options = @criteria_options.with_indifferent_access
        @criteria.merge!(params.reject { |key, _| %w(controller action ns model format api).include?(key) })
        @criteria.each { |key, value| @criteria[key] = Cenit::Utility.json_value_of(value) }
        unless (@template_options = Cenit::Utility.json_value_of(request.headers['X-Template-Options'])).is_a?(Hash)
          @template_options = {}
        end
        @template_options = @template_options.with_indifferent_access
        if @criteria && klass
          %w(only ignore embedding).each do |option|
            if @criteria.key?(option) && !klass.property?(option)
              unless (value = @criteria.delete(option)).is_a?(Array)
                value = value.to_s.split(',').collect(&:strip)
              end
              @template_options[option] = value
            end
          end
        end
        if (fields_option = @criteria_options.delete(:fields)) || !@template_options.key?(:only)
          fields_option =
            case fields_option
            when Array
              fields_option
            when Hash
              fields_option.collect { |field, presence| presence.to_b ? field : nil }.select(&:presence)
            else
              fields_option.to_s.split(',').collect(&:strip)
            end
          @template_options[:only] = fields_option
        end
        unless @template_options.key?(:viewport) || @webhook_body.blank?
          @template_options[:viewport] = @webhook_body
        end
        unless @template_options[:viewport] || @template_options.key?(:include_id)
          @template_options[:include_id] = true
        end
      end
    end

    private

    attr_reader :webhook_body

    class BasicPayload

      attr_reader :config

      def initialize(config)
        @config =
          {
            method_suffix: case config[:content_type]
                           when 'application/json'
                             :from_json
                           when 'application/xml'
                             :from_xml
                           else
                             :from
                           end,
            message: ''
          }.merge(config || {})
        controller = config[:controller]
        @data_type =
          begin
            controller.send(:get_data_type, (@root = controller.request.params[:model] || controller.request.headers['data-type']))
          rescue Exception
            nil
          end
      end

      def create_method
        "create_#{config[:method_suffix]}"
      end

      def update_method
        suffix = config[:method_suffix]
        if suffix == :from
          'fill_from'
        else
          suffix
        end
      end

      def message
        config[:message]
      end

      def each_root(&block)
        block.call(@root, message) if block
      end

      def each(&block)
        if @data_type
          block.call(@data_type.slug, message)
        else
          each_root(&block)
        end
      end

      def process_item(item, data_type, options)
        item
      end

      def data_type_for(root)
        @data_type && @data_type.slug == root ? @data_type : config[:controller].send(:get_data_type, root)
      end
    end

    class JSONPayload < BasicPayload

      def message
        @message ||= JSON.parse(msg = super)
      end

      def each_root(&block)
        if message.is_a?(Hash)
          message.each { |root, message| block.call(root, message) }
        else
          fail "JSON object payload expected but #{message.class} found"
        end
      end
    end

    class XMLPayload < BasicPayload

      def each_root(&block)
        if (roots = Nokogiri::XML::DocumentFragment.parse(message).element_children)
          roots.each do |root|
            if (elements = root.element_children)
              elements.each { |e| block.call(root.name, e) }
            end
          end
        end if block
      end
    end

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
  end
end

module Setup

  class JsonDataType
    def digest(request, options = {})
      data =
        if request.get?
          merged_schema(options)
        else
          request.body.rewind #TODO Do not run save_request_data for digest
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

  class FileDataType

    def post_digest(request, options = {})
      request.body.rewind
      file = create_from(request.body, options)
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
end

require 'mongoff/grid_fs/file'

module Mongoff
  module GridFs
    class File

      def post_digest(request, options = {})
        request.body.rewind
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
