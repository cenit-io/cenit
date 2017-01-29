module Api::V2
  class ApiController < ApplicationController
    before_action :authorize_account, :save_request_data, except: [:new_user, :cors_check, :auth]
    before_action :find_item, only: [:show, :destroy, :pull, :run]
    before_action :authorize_action, except: [:auth, :new_user, :cors_check, :push]
    rescue_from Exception, :with => :exception_handler
    respond_to :json

    def cors_check
      self.cors_header
      render :text => '', :content_type => 'text/plain'
    end

    def index
      page = get_page
      res =
        {
          json: { error: 'no model found' },
          status: :not_found
        }
      if (klass = self.klass)
        @items =
          if @criteria.present?
            select_items
          else
            accessible_records.page(page)
          end

        option = { including: :_type }
        option[:only] = @only if @only
        option[:ignore] = @ignore if @ignore
        option[:embedding] = @embedding if @embedding
        option[:include_id] = true
        items_data = @items.map do |item|
          hash = item.default_hash(option)
          hash.delete('_type') if item.class.eql?(klass)
          @view.nil? ? hash : hash[@view]
        end
        count = @items.count
        res =
          {
            json: {
              total_pages: (count*1.0/Kaminari.config.default_per_page).ceil,
              current_page: page,
              count: count,
              @model.pluralize => items_data
            }
          }
      end
      render res
    end

    def show
      if @item.orm_model.data_type.is_a?(Setup::FileDataType)
        send_data @item.data, filename: @item[:filename], type: @item[:contentType]
      else
        option = {}
        option[:only] = @only if @only
        if @ignore
          option[:ignore] = @ignore
        end
        if @embedding
          option[:embedding] = @embedding
        end
        option[:include_id] = true
        render json: @view.nil? ? @item.to_hash(option) : @item.to_hash(option)[@view]
      end
    end

    def content
      render json: @view.nil? ? @item.to_hash : { @view => @item.to_hash[@view] }
    end

    def push
      response =
        {
          success: success_report = Hash.new { |h, k| h[k] = [] },
          errors: broken_report = Hash.new { |h, k| h[k] = [] }
        }
      @payload.each do |root, message|
        @model = root
        if authorized_action? && (data_type = @payload.data_type_for(root))
          message = [message] unless message.is_a?(Array)
          message.each do |item|
            options = @payload.create_options
            model = data_type.records_model
            if model.is_a?(Class) && model < FieldsInspection
              options[:inspect_fields] = Account.current.nil? || !Account.current_super_admin?
            end
            if (record = data_type.send(@payload.create_method,
                                        @payload.process_item(item, data_type),
                                        options)).errors.blank?
              success_report[root.pluralize] << record.inspect_json(include_id: :id, inspect_scope: options[:create_collector])
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
      response =
        {
          success: success_report = {},
          errors: broken_report = {}
        }
      @payload.each do |root, message|
        if (data_type = @payload.data_type_for(root))
          message = [message] unless message.is_a?(Array)
          message.each do |item|
            begin
              options = @payload.create_options.merge(primary_field: @primary_field)
              model = data_type.records_model
              if model.is_a?(Class) && model < FieldsInspection
                options[:inspect_fields] = Account.current.nil? || !Account.current_super_admin?
              end
              if (record = data_type.send(@payload.create_method,
                                          @payload.process_item(item, data_type),
                                          options)).errors.blank?
                success_report[root] = record.inspect_json(include_id: :id, inspect_scope: options[:create_collector])
              else
                broken_report[root] = { errors: record.errors.full_messages, item: item }
              end
            rescue Exception => ex
              broken_report[root] = { errors: ex.message, item: item }
            end
          end
        else
          broken_report[root] = 'no model found'
        end
      end
      response.delete(:success) if success_report.blank?
      response.delete(:errors) if broken_report.blank?
      render json: response
    end

    def destroy
      @item.destroy
      render json: { status: :ok }
    end

    def run
      if @item.is_a?(Setup::Algorithm)
        begin
          execution = Setup::AlgorithmExecution.process(algorithm_id: @item.id,
                                                        input: @webhook_body,
                                                        skip_notification_level: true)
          execution.reload
          render json: execution.to_hash(include_blanks: false)
        rescue Exception => ex
          render json: { error: ex.message }, status: 406
        end
      else
        render json: { status: :not_allowed }, status: 405
      end
    end

    def pull
      if @item.is_a?(Setup::CrossSharedCollection)
        begin
          pull_request = @webhook_body.present? ? JSON.parse(@webhook_body) : {}
          if pull_request.delete('asynchronous').to_b || @item.pull_asynchronous
            render json: @item.pull(pull_request).to_json
          else
            pull_request = Cenit::Actions.pull(@item, pull_request)
            pull_request.each { |key, value| pull_request.delete(key) unless value.present? }
            status = :ok
            if pull_request[:missing_parameters] or (errors = pull_request[:errors].present?)
              pull_request.delete(:updated_records)
              status = errors ? 202 : :bad_request
            elsif (updated_records = pull_request[:updated_records])
              updated_records.each do |key, records|
                updated_records[key] = records.collect { |record| { id: record.id.to_s } }
              end
            end
            render json: pull_request, status: status
          end
        rescue Exception => ex
          render json: { error: ex.message, status: :bad_request }
        end
      else
        render json: { status: :not_allowed }
      end
    end

    def auth
      authorize_account
      if Account.current
        self.cors_header
        render json: { status: 'Sucess Auth' }, status: 200
      else
        self.cors_header
        render json: { status: 'Error Auth' }, status: 401
      end
    end

    def new_user
      data = (JSON.parse(@webhook_body) rescue {}).keep_if { |key, _| %w(email password password_confirmation token code).include?(key) }
      data = data.with_indifferent_access
      data.reverse_merge!(email: params[:email], password: pwd = params[:password], password_confirmation: params[:password_confirmation] || pwd)
      status = :not_acceptable
      response =
        if (token = data[:token] || params[:token])
          if (captcha_token = CaptchaToken.where(token: token).first)
            if (code = data[:code] || params[:code])
              if code == captcha_token.code
                data.merge!(captcha_token.data || {}) { |_, left, right| left || right }
                captcha_token.destroy
                _, status, response = create_user_with(data)
                response
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

    protected

    def create_user_with(data)
      status = :not_acceptable
      data[:password] ||= Devise.friendly_token
      data[:password_confirmation] ||= data[:password]
      current_account = Account.current
      begin
        Account.current = nil
        (user = ::User.new(data)).save
      rescue
        user #TODO Handle sending confirmation email error
      ensure
        Account.current = current_account
      end
      response=
        if user.errors.blank?
          status = :ok
          { number: user.number, token: user.authentication_token }
        else
          user.errors.to_json
        end
      [user, status, response]
    end

    def get_limit
      if (limit = @criteria.delete(:limit))
        if limit == '0'
          limit = Kaminari.config.default_per_page.to_s
        end
        limit = [Kaminari.config.default_per_page, limit.to_i].min
      else
        limit = Kaminari.config.default_per_page
      end
      limit
    end

    def get_page
      if (page = @criteria.delete(:page))
        page = page.to_i
      else
        page = 1
      end
      page
    end

    def select_items
      asc = true
      if (order = @criteria.delete(:order))
        order.strip!
        asc = !order.match(/^-.*/)
      end

      limit = get_limit
      page = get_page

      @compound_query = { :exists => false }
      if (where_data = @criteria.delete(:where))
        wh = JSON.parse(where_data)

        if wh.keys.include?('or')
          @compound_query[:exists] = true
          @compound_query[:operands] = wh['or']
        end

        wh1 = wh.select { |k, _| !['or'].include?(k) }
        wh1.each { |field, value|
          value.each { |k, v|
            instance_eval("@criteria[:#{field}.#{k}]=#{v}")
          }
        }

      end

      items = accessible_records.page(page).where(@criteria).limit(limit)

      if @compound_query[:exists]
        t = @compound_query[:operands].map {
          |h| instance_eval("{:#{h.keys.first}.#{h.values.first.keys.first} => #{h.values.first.values.first}}")
        }
        items = items.or(*t)
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
      key = params.delete('X-User-Access-Key')
      key = request.headers['X-User-Access-Key'] || key
      token = params.delete('X-User-Access-Token')
      token = request.headers['X-User-Access-Token'] || token
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
      User.current = user || (Account.current ? Account.current.owner : nil)
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
          else
            @_action_name.to_sym
          end
        unless @ability.can?(action_symbol, @item || klass)
          success = false
          unless options[:skip_response]
            responder = Cenit::Responder.new(@request_id, :unauthorized)
            render json: responder, root: false, status: responder.code
          end
        end
      else
        success = false
        unless options[:skip_response]
          render json: { error: 'no model found' }, status: :not_found
        end
      end
      cors_header
      success
    end

    def cors_header
      headers['Access-Control-Allow-Origin'] = request.headers['Origin'] || ::Cenit.homepage
      headers['Access-Control-Allow-Credentials'] = false
      headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Accept, Content-Type, X-User-Access-Key, X-User-Access-Token'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
      headers['Access-Control-Max-Age'] = '1728000'
    end

    def exception_handler(exception)
      responder = Cenit::Responder.new(@request_id, exception)
      render json: responder, root: false, status: responder.code
      false
    end

    def find_item
      if (@item = accessible_records.where(id: params[:id]).first)
        true
      else
        render json: { status: 'item not found' }, status: :not_found
        false
      end
    end

    def get_data_type_by_slug(slug)
      if slug
        @data_types[slug] ||=
          if @ns_slug == 'setup'
            Setup::BuildInDataType["Setup::#{slug.camelize}"] || Setup::BuildInDataType[slug.camelize]
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
      @only = params[:only].split(',') if params[:only]
      @ignore = params[:ignore].split(',') if params[:ignore]
      @embedding = params[:embedding].split(',') if params[:embedding]
      @primary_field = params[:primary_field]
      @include_root = params[:include_root]
      @pretty = params[:pretty]
      @view = params[:view]
      @format = params[:format]
      @path = "#{params[:path]}.#{params[:format]}" if params[:path] && params[:format]
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
      @criteria = params.to_hash.with_indifferent_access.reject { |key, _| %w(controller action ns model id field path format view api only ignore primary_field pretty include_root embedding).include?(key) }
    end

    private

    attr_reader :webhook_body

    class BasicPayload

      attr_reader :config
      attr_reader :create_options

      def initialize(config)
        @config =
          {
            create_method: case config[:content_type]
                           when 'application/json'
                             :create_from_json
                           when 'application/xml'
                             :create_from_xml
                           else
                             :create_from
                           end,
            message: ''
          }.merge(config || {})
        controller = config[:controller]
        @data_type = controller.send(:get_data_type, (@root = controller.request.params[:model] || controller.request.headers['data-type'])) rescue nil
        @create_options = { create_collector: Set.new }
        create_options_keys.each { |option| @create_options[option.to_sym] = controller.request[option] }
      end

      def create_method
        config[:create_method]
      end

      def create_options_keys
        %w(filename metadata encoding add_only)
      end

      def each_root(&block)
        block.call(@root, config[:message]) if block
      end

      def each(&block)
        if @data_type
          block.call(@data_type.slug, config[:message])
        else
          each_root(&block)
        end
      end

      def process_item(item, data_type)
        item
      end

      def data_type_for(root)
        @data_type && @data_type.slug == root ? @data_type : config[:controller].send(:get_data_type, root)
      end
    end

    class JSONPayload < BasicPayload

      def each_root(&block)
        JSON.parse(config[:message]).each { |root, message| block.call(root, message) } if block
      end

      def process_item(item, data_type)
        data_type.is_a?(Setup::FileDataType) ? item.to_json : item
      end
    end

    def create_options_keys
      super + %w(only)
    end

    class XMLPayload < BasicPayload

      def each_root(&block)
        if (roots = Nokogiri::XML::DocumentFragment.parse(config[:message]).element_children)
          roots.each do |root|
            if (elements = root.element_children)
              elements.each { |e| block.call(root.name, e) }
            end
          end
        end if block
      end

      def process_item(item, data_type)
        data_type.is_a?(Setup::FileDataType) ? item.to_xml : item
      end
    end
  end
end
