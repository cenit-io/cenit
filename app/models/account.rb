require 'cenit/heroku_client'

class Account
  include Mongoid::Document
  include NumberGenerator

  belongs_to :owner, class_name: User.to_s, inverse_of: nil
  has_many :users, class_name: User.to_s, inverse_of: :account

  field :name, type: String
  field :meta, type: Hash, default: {}

  belongs_to :tenant_account, class_name: Account.to_s, inverse_of: nil

  field :notification_level, type: Symbol, default: :warning
  field :notifications_listed_at, type: DateTime

  field :time_zone, type: String, default: '+00:00'

  validates_inclusion_of :notification_level, in: ->(a) { a.notification_level_enum }

  before_save :inspect_updated_fields, :init_heroku_db, :validates_configuration

  def inspect_updated_fields
    changed_attributes.keys.each do |attr|
      reset_attribute!(attr) unless %w(notification_level time_zone).include?(attr)
    end unless new_record? || Account.current_super_admin?
    errors.add(:tenant_account, 'is sealed and can not be inspected') if tenant_account && tenant_account.sealed?
    errors.blank?
  end

  def init_heroku_db
    if ENV['HEROKU_MLAB'] && new_record?
      heroku_name = "hub-#{id.to_s}"
      app = HerokuClient::App.create(heroku_name)
      if app
        if app.add_addon(ENV['HEROKU_MONGOPLAN'] || 'mongolab:sandbox')
          meta['db_name'] = heroku_name
          meta['db_uri'] = app.get_variable(ENV['HEROKU_MONGOVAR'] || 'MONGOLAB_URI')
        end
      end
    end
    true
  end

  TIME_ZONE_REGEX = /((\+|-)((1[0-3])|(0\d)):\d\d)/

  def validates_configuration
    errors.add(:time_zone, 'is not valid') unless TIME_ZONE_REGEX.match(time_zone)
    errors.blank?
  end

  def time_zone_offset
    TIME_ZONE_REGEX.match(time_zone).to_s
  end

  def notification_level_enum
    Setup::Notification.type_enum
  end

  def label
    owner.present? ? owner.label : Account.to_s + '#' + id.to_s
  end

  def owner?(user)
    owner == user
  end

  def generate_number(options = {})
    options[:prefix] ||= 'A'
    super(options)
  end

  def super_admin?
    owner && owner.super_admin?
  end

  def sealed?
    owner && owner.sealed?
  end

  def time_zone_enum
    ActiveSupport::TimeZone.all.collect { |e| "#{e.name} | #{e.formatted_offset}" }
  end

  def cenit_collections_names
    self.class.cenit_collections_names(self)
  end

  def each_cenit_collection(&block)
    self.class.each_cenit_collection(self, &block)
  end

  class << self

    def current_executor
      if (current_account = current)
        ((user = current_account.owner) && user.super_admin? && current_account.tenant_account) ||
          current_account
      end
    end

    def current
      Thread.current[:current_account]
    end

    def current=(account)
      Thread.current[:current_account] = account
      if User.respond_to?(:current=) #TODO Optimize here!
        User.current = account ? account.owner : nil
      end
    end

    def current_super_admin?
      current && current.super_admin?
    end

    def create_with_owner(params={})
      account = new(params)
      if (owner = account.owner)
        owner.roles << ::Role.where(name: :admin).first unless owner.roles.any? { |role| role.name.to_s == :admin.to_s }
        account.users << owner
        account.save
      end
      account
    end

    def set_current_with_connection(key, token)
      all.each do |account|
        self.current = account
        if (connection = Setup::Connection.where(number: key).first).present? && Devise.secure_compare(connection.token, token)
          return connection
        end
      end
      self.current = nil
    end

    def tenant_collection_prefix(options = {})
      sep = options[:separator] || ''
      acc_id =
        (options[:account] && options[:account].id) ||
          options[:account_id] ||
          (!options.has_key?(:account) &&
            !options.has_key?(:account_id) &&
            current &&
            (((user = current.owner) && user.super_admin? && current.tenant_account.present?) ?
              current.tenant_account.id :
              current.id))
      acc_id ? "acc#{acc_id}#{sep}" : ''
    end

    def tenant_collection_name(model_name, options = {})
      model_name = model_name.to_s
      options[:separator] ||= '_'
      tenant_collection_prefix(options) + model_name.collectionize
    end

    def data_type_collection_name(data_type)
      tenant_collection_name(data_type.data_type_name)
    end

    def cenit_collections_names(account = current)
      db_name = Mongoid.default_client.database.name
      Mongoid.default_client[:'system.namespaces']
        .find(name: Regexp.new("\\A#{db_name}.#{tenant_collection_prefix(account: account)}_[^$]+\\Z"))
        .collect { |doc| doc['name'] }
        .collect { |name| name.gsub(Regexp.new("\\A#{db_name}\."), '') }
    end

    def each_cenit_collection(account = current, &block)
      cenit_collections_names(account).each do |collection_name|
        block.call(Mongoid.default_client[collection_name.to_sym])
      end
    end
  end
end
