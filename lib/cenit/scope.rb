module Cenit
  class Scope

    def initialize(scope = '')
      @openid = Set.new
      @access = {}
      @super_methods = Set.new
      scope = scope.to_s.strip
      while scope.present?
        openid, scope = split(scope, %w(openid email profile address phone offline_access auth))
        @offline_access ||= openid.delete(:offline_access)
        @auth ||= openid.delete(:auth)
        if openid.present? && !openid.include?(:openid)
          openid.clear
          fail
        end
        @openid.merge(openid)
        methods, scope = split(scope, %w(get post put delete))
        fail unless methods.present?
        methods = Set.new(methods)
        access = @access[methods] || {}
        if scope.present?
          ns_begin, ns_end, next_idx =
            if scope.start_with?((c = "'")) || scope.start_with?((c = '"'))
              [1, (next_idx = scope.index(c, 1)) - 1, next_idx + 1]
            else
              quad_dot_index = scope.index('::')
              space_index = scope.index(' ')
              if quad_dot_index && (space_index.nil? || space_index > quad_dot_index)
                [0, quad_dot_index - 1, quad_dot_index]
              elsif quad_dot_index.nil? && space_index
                [0, space_index - 1, space_index + 1]
              elsif quad_dot_index.nil? && space_index.nil?
                [0, scope.length, scope.length]
              else
                fail
              end
            end
          if ns_end >= ns_begin
            ns = scope[ns_begin..ns_end]
            access[ns] ||= Set.new
            scope = scope.from(next_idx) || ''
            if scope.start_with?('::')
              scope = scope.from(2)
              if scope.start_with?((c = "'")) || scope.start_with?((c = '"'))
                model = scope[1, scope.index(c, 1) - 1]
                scope = scope.from(model.length + 2)
                fail if scope.present? && !scope.start_with?(' ')
              else
                model = scope[0..(scope.index(' ') || scope.length) - 1]
                scope = scope.from(model.length)
              end
              access[ns] << model
            end
          else
            fail
          end
          access[ns]
        end
        if access.present?
          @access[methods] = access unless @access.has_key?(methods)
        else
          @super_methods.merge(methods)
        end
        scope = scope.strip
      end
    rescue
      @access.clear
    end

    def valid?
      openid.present? || access.present?
    end

    def to_s
      s =
        (auth? ? 'auth ' : '') +
          (offline_access? ? 'offline_access ' : '') +
          (openid? ? openid.to_a.join(' ') + ' ' : '') +
          access.collect do |methods, accss|
            methods.to_a.join(' ') +
              if accss.present?
                ' ' + accss.collect do |ns, data_types|
                  ns = space(ns)
                  if data_types.blank?
                    ns
                  else
                    data_types.collect { |model| "#{ns}::#{space(model)}" }.join(' ')
                  end
                end.join(' ')
              else
                ''
              end
          end.join(' ') + ' ' + super_methods.to_a.join(' ')
      s.strip
    end

    def descriptions
      d = []
      d << 'View your email' if email?
      d << 'View your basic profile' if profile?
      access.each do |methods, accss|
        accss.each do |ns, data_types|
          ns = space(ns)
          d << methods.to_a.to_sentence +
            ' records from data type' +
            (data_types.size == 1 ? ' ' : 's ') +
            data_types.collect { |model| "#{ns}::#{space(model)}" }.to_sentence
        end
      end
      if super_methods.present?
        d << "#{super_methods.to_a.to_sentence} records from any data type"
      end
      d
    end

    def auth?
      auth.present?
    end

    def openid?
      openid.include?(:openid)
    end

    def email?
      openid.include?(:email)
    end

    def profile?
      openid.include?(:profile)
    end

    def offline_access?
      offline_access.present?
    end

    def merge(other)
      merge = self.class.new
      merge.instance_variable_set(:@auth, auth || other.instance_variable_get(:@auth))
      merge.instance_variable_set(:@offline_access, offline_access || other.instance_variable_get(:@offline_access))
      merge.instance_variable_set(:@openid, (openid + other.instance_variable_get(:@openid)))
      merge.instance_variable_set(:@super_methods, super_methods + other.super_methods)
      [
        access,
        other.instance_variable_get(:@access)
      ].each do |access|
        access.each do |methods, other_accss|
          merge.merge_access(methods, other_accss)
        end
      end
      merge
    end

    protected

    attr_reader :auth, :offline_access, :openid, :methods, :nss, :data_types, :access, :super_methods

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
      if counters.values.all? { |v| v ==1 }
        [counters.keys.collect(&:to_sym), scope]
      else
        [[], scope]
      end
    end

    def merge_access(other_methods, other_accss)
      other_methods = other_methods - super_methods
      if other_methods.present?
        other_accss.each do |other_ns, other_data_types|
          if (data_types = access[other_ns]).present?
            if other_data_types.present?
              data_types.merge(other_data_types)
            else
              data_types.clear
            end
          else
            access[other_methods] = other_accss.deep_dup
          end
        end
      end
    end
  end
end