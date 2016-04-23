module Cenit
  class Scope

    def initialize(scope = '')
      scope = scope.to_s
      @nss = Set.new
      @data_types = Hash.new { |h, k| h[k] = Set.new }
      scope = scope.to_s.strip
      @openid, scope = split(scope, %w(openid email profile address phone offline_access))
      @offline_access = openid.delete(:offline_access)
      if openid.present? && !openid.include?(:openid)
        openid.clear
        fail
      end
      @methods, scope = split(scope, %w(get post put delete))
      while scope.present?
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
            @data_types[ns] << model
          else
            @nss << ns
          end
        else
          fail
        end
        scope = scope.strip
      end
    rescue
      @nss.clear
      @data_types.clear
    end

    def valid?
      openid.present? || (methods.present? && (nss.present? || data_types.present?))
    end

    def to_s
      (openid.present? ? openid.join(' ') + ' ' : '') +
        methods.join(' ') + ' ' +
        nss.collect { |ns| space(ns) }.join(' ') + (nss.present? ? ' ' : '') +
        data_types.collect { |ns, set| set.collect { |model| "#{space(ns)}::#{space(model)}" } }.join(' ')
    end

    def descriptions
      d = []
      d << 'View your email' if email?
      d << 'View your basic profile' if profile?
      if methods.present?
        d << methods.to_sentence + ' records from ' +
          if nss.present?
            'namespace' + (nss.size == 1 ? ' ' : 's ') + nss.collect { |ns| space(ns) }.to_sentence
          else
            ''
          end + (nss.present? && data_types.present? ? ', and ' : '') +
          if data_types.present?
            'data type' + (data_types.size == 1 ? ' ' : 's ') + data_types.collect { |ns, set| set.collect { |model| "#{space(ns)}::#{space(model)}" } }.flatten.to_sentence
          else
            ''
          end
      end
      d << 'Do all these on your behalf.' if offline_access?
      d
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
      merge.instance_variable_set(:@offline_access, offline_access || other.instance_variable_get(:@offline_access))
      merge.instance_variable_set(:@openid, (openid + other.instance_variable_get(:@openid)).uniq)
      merge.instance_variable_set(:@methods, (methods + other.instance_variable_get(:@methods)).uniq)
      merge.instance_variable_set(:@nss, nss + other.instance_variable_get(:@nss))
      merge.instance_variable_set(:@data_types, data_types.merge(other.instance_variable_get(:@data_types)))
      merge
    end

    private

    attr_reader :offline_access, :openid, :methods, :nss, :data_types

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
  end
end