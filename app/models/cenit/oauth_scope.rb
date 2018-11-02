module Cenit
  class OauthScope

    AUTH_TOKEN = :auth

    OFFLINE_ACCESS_TOKEN = :offline_access

    MULTI_TENANT_TOKEN = :multi_tenant

    OPENID_TOKEN = :openid

    OPENID_EMAIL_TOKEN = :email

    OPENID_PROFILE_TOKEN = :profile

    OPENID_TOKENS = [OPENID_TOKEN, OPENID_EMAIL_TOKEN, OPENID_PROFILE_TOKEN].freeze

    CREATE_TOKEN = :create

    READ_TOKEN = :read

    UPDATE_TOKEN = :update

    DELETE_TOKEN = :delete

    DIGEST_TOKEN = :digest

    ACCESS_TOKENS = [CREATE_TOKEN, READ_TOKEN, UPDATE_TOKEN, DELETE_TOKEN, DIGEST_TOKEN].freeze

    TOKENS = ([AUTH_TOKEN, OFFLINE_ACCESS_TOKEN, MULTI_TENANT_TOKEN] + OPENID_TOKENS + ACCESS_TOKENS).freeze

    NON_ACCESS_TOKENS = ([AUTH_TOKEN, OFFLINE_ACCESS_TOKEN, MULTI_TENANT_TOKEN] + OPENID_TOKENS).freeze

    def initialize(scope = '')
      @openid = Set.new
      @access = {}
      @super_methods = Set.new
      scope = scope.to_s.strip
      openid_expected = false
      while scope.present?
        openid, scope = split(scope, NON_ACCESS_TOKENS)
        fail if openid.empty? && openid_expected
        @offline_access ||= openid.delete(OFFLINE_ACCESS_TOKEN)
        @auth ||= openid.delete(AUTH_TOKEN)
        @multi_tenant ||= openid.delete(MULTI_TENANT_TOKEN)
        @openid.merge(openid)
        if scope.present?
          methods, scope = split(scope, ACCESS_TOKENS)
          methods = Set.new(methods)
          criterion = @access.delete(methods) || []
          criteria = {}
          if scope.present? && scope.start_with?('{')
            openid_expected = false
            i = 1
            stack = 1
            while stack > 0 && i < scope.length
              case scope[i]
              when '{'
                stack += 1
              when '}'
                stack -= 1
              end
              i += 1
            end
            criteria = JSON.parse(scope[0, i])
            scope = scope.from(i)
          else
            openid_expected = true
          end
          if criteria.present?
            criterion << criteria
            @access[methods] = criterion
          else
            @super_methods.merge(methods)
          end
        end
        scope = scope.strip
      end
      fail if @openid.present? && !@openid.include?(OPENID_TOKEN)
      normalized_access = {}
      @access.each do |methods, criterion|
        methods.each do |method|
          next if super_methods.include?(method)
          if (normalized_criteria = normalized_access[method])
            normalized_criteria.concat(criterion)
          else
            normalized_access[method] = criterion
          end
        end
      end
      @access = normalized_access
    rescue
      @openid.clear
      @access.clear
      @super_methods.clear
    end

    def criteria_for(method)
      return unless (criterion = access[method])
      if criterion.size == 1
        criterion[0]
      else
        { '$or' => criterion }
      end
    end

    def each_criteria
      access.each_key { |method| yield(method, criteria_for(method)) }
    end

    def access_by_ids
      scope = clone
      scope.each_criteria do |method, criteria|
        unless criteria.size == 1 && (id_cond = criteria['_id']).is_a?(Hash) &&
          id_cond.size == 1 && id_cond['$in'].is_a?(Array)
          ids = Setup::DataType.where(criteria).collect(&:id).collect(&:to_s)
          scope.instance_variable_get(:@access)[method] = [{ '_id' => { '$in' => ids } }]
        end
      end
      scope
    end

    def valid?
      auth? || offline_access? || multi_tenant? || openid.present? || access.present? || super_methods.present?
    end

    def to_s
      if valid?
        s = access_less_scope
        each_criteria do |method, criteria|
          s += " #{method} #{criteria.to_json}"
        end
        s += ' ' + super_methods.to_a.join(' ')
        s.strip
      else
        '<invalid scope>'
      end
    end

    def descriptions
      d = []
      if valid?
        d << 'View your email' if email?
        d << 'View your basic profile' if profile?
        each_criteria do |method, criteria|
          d << "#{method} records from data types where #{criteria.to_json}"
        end
        if super_methods.present?
          d << "#{super_methods.to_a.to_sentence} records from any data type"
        end
      else
        d << '<invalid scope>'
      end
      d
    end

    def auth?
      auth.present?
    end

    def openid?
      openid.include?(OPENID_TOKEN)
    end

    def email?
      openid.include?(OPENID_EMAIL_TOKEN)
    end

    def profile?
      openid.include?(OPENID_PROFILE_TOKEN)
    end

    def offline_access?
      offline_access.present?
    end

    def multi_tenant?
      multi_tenant.present?
    end

    def clone
      merge('')
    end

    def merge(other_scope)
      other_scope = self.class.new(other_scope.to_s) unless other_scope.is_a?(self.class)
      merge = self.class.new
      merge.instance_variable_set(:@auth, auth || other_scope.instance_variable_get(:@auth))
      merge.instance_variable_set(:@offline_access, offline_access || other_scope.instance_variable_get(:@offline_access))
      merge.instance_variable_set(:@multi_tenant, multi_tenant || other_scope.instance_variable_get(:@multi_tenant))
      merge.instance_variable_set(:@openid, (openid + other_scope.instance_variable_get(:@openid)))
      merge.instance_variable_set(:@super_methods, super_methods + other_scope.super_methods)
      [
        access,
        other_scope.instance_variable_get(:@access)
      ].each do |access|
        access.each do |method, other_criterion|
          merge.merge_access(method, other_criterion)
        end
      end
      merge
    end

    def >(other_scope)
      other_scope = Cenit::OauthScope.new(other_scope.to_s) unless other_scope.is_a?(Cenit::OauthScope)
      return false if (other_scope.auth? && !auth?) ||
        (other_scope.offline_access? && !offline_access?) ||
        (other_scope.multi_tenant? && !multi_tenant?) ||
        !other_scope.openid_set.subset?(openid_set) ||
        !other_scope.super_methods_set.subset?(super_methods_set)
      other_scope.each_criteria { |method, _| return false unless criteria_for(method) }
      access_by_ids.each_criteria do |method, criteria|
        next unless (other_criteria = other_scope.criteria_for(method))
        criteria = { '$and' => [other_criteria, '_id' => { '$nin' => criteria['_id']['$in'] }] }
        return false if Setup::DataType.where(criteria).exists?
      end
      true
    end

    def diff(other_scope)
      other_scope = self.class.new(other_scope.to_s) unless other_scope.is_a?(self.class)
      diff = self.class.new
      if auth? && !other_scope.auth?
        diff.instance_variable_set(:@auth, true)
      end
      if offline_access? && !other_scope.offline_access?
        diff.instance_variable_set(:@offline_access, true)
      end
      if multi_tenant? && !other_scope.multi_tenant?
        diff.instance_variable_set(:@multi_tenant, true)
      end
      if (openid = self.openid - other_scope.instance_variable_get(:@openid)).present?
        openid << OPENID_TOKEN
        diff.instance_variable_set(:@openid, openid)
      end
      if (super_methods = self.super_methods - other_scope.instance_variable_get(:@super_methods)).present?
        diff.instance_variable_set(:@super_methods, super_methods)
      end
      other_scope = other_scope.access_by_ids
      diff_access = diff.instance_variable_get(:@access)
      each_criteria do |method, criteria|
        diff_access[method] = [
          if (other_criteria = other_scope.criteria_for(method))
            { '$and' => [criteria, '_id' => { '$nin' => other_criteria['_id']['$in'] }] }
          else
            criteria
          end
        ]
      end
      diff
    end

    def openid_set
      openid.dup
    end

    def super_method?(method)
      super_methods.include?(method)
    end

    def super_methods_set
      super_methods.dup
    end

    protected

    attr_reader :auth, :offline_access, :openid, :access, :super_methods, :multi_tenant

    def space(str)
      str.index(' ') ? "'#{str}'" : str
    end

    def split(scope, tokens)
      scope += ' '
      counters = Hash.new { |h, k| h[k] = 0 }
      while (method = tokens.detect { |m| scope.start_with?("#{m} ") })
        counters[method] += 1
        scope = scope.from(method.length).strip + ' '
      end
      scope = scope.strip
      if counters.values.all? { |v| v == 1 }
        [counters.keys.collect(&:to_sym), scope]
      else
        [[], scope]
      end
    end

    def merge_access(other_method, other_criterion)
      return if super_methods.include?(other_method)
      (access[other_method] ||= []).concat(other_criterion).uniq!
    end

    def access_less_scope
      ((auth? ? "#{AUTH_TOKEN} " : '') +
        (offline_access? ? "#{OFFLINE_ACCESS_TOKEN} " : '') +
        (multi_tenant? ? "#{MULTI_TENANT_TOKEN} " : '') +
        (openid? ? openid.to_a.join(' ') + ' ' : '')).strip
    end

    def can?(action, model)
      return false unless (data_type = model.try(:data_type))
      method =
        case action
        when :new, :upload_file
          Cenit::OauthScope::CREATE_TOKEN
        when :edit, :update
          Cenit::OauthScope::UPDATE_TOKEN
        when :index, :show
          Cenit::OauthScope::READ_TOKEN
        when :destroy
          Cenit::OauthScope::DELETE_TOKEN
        when :digest
          Cenit::OauthScope::DIGEST_TOKEN
        else
          nil
        end
      return true if super_method?(method)
      criteria = access_by_ids.criteria_for(method)
      criteria.present? && criteria['_id']['$in'].include?(data_type.id.to_s)
    end
  end
end