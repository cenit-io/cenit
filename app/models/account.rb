require 'cenit/heroku_client'

class Account
  include Setup::CenitUnscoped
  include Cenit::MultiTenancy
  include CredentialsGenerator
  include FieldsInspection
  include TimeZoneAware
  include ObserverTenantLookup

  DEFAULT_INDEX_MAX_ENTRIES = 100

  inspect_fields :name, :notification_level, :time_zone, :index_max_entries

  build_in_data_type.with(:name, :notification_level, :time_zone, :number, :authentication_token)
  build_in_data_type.protecting(:number, :authentication_token)
  build_in_data_type.and(
    properties: {
      notification_level: {
        enum: Setup::SystemNotification.type_enum
      },
      time_zone: {
        enum: time_zone_enum
      },
      number: {
        type: 'string',
        edi: {
          segment: 'key'
        }
      },
      authentication_token: {
        type: 'string',
        edi: {
          segment: 'token'
        }
      }
    }
  )

  deny :all

  belongs_to :owner, class_name: User.to_s, inverse_of: :accounts
  has_and_belongs_to_many :users, class_name: User.to_s, inverse_of: :member_accounts

  field :name, type: String
  field :meta, type: Hash, default: {}

  field :notification_level, type: StringifiedSymbol, default: :warning
  field :notifications_listed_at, type: DateTime

  field :index_max_entries, type: Integer, default: DEFAULT_INDEX_MAX_ENTRIES

  validates_uniqueness_of :name, scope: :owner
  validates_inclusion_of :notification_level, in: ->(a) { a.notification_level_enum }

  before_validation do
    if self.owner ||= User.current
      if (n = name.to_s.strip).empty?
        n = owner.email
        c = 0
        while Account.where(owner_id: owner_id, name: n).exists?
          n = "#{owner.email} (#{c += 1})"
        end
      end
      self.name = n
    else
      errors.add(:base, 'can not be created outside current user context')
    end
    errors.blank?
  end

  before_create :check_creation_enabled

  before_save :init_heroku_db, :validates_configuration

  after_destroy { clean_up }

  def check_creation_enabled
    unless @for_create
      errors.add(:base, 'Tenant creation is disabled') if Cenit.tenant_creation_disabled && !User.current_super_admin?
    end
    errors.blank?
  end

  def api_account
    self
  end

  def user
    owner
  end

  def read_raw_attribute(name)
    (!(value = super).nil? &&

      (new_record? || !self.class.build_in_data_type.protecting?(name) ||
        ((current_user = User.try(:current)) && current_user.owns?(self))) &&

      value) || nil
  end

  def inspect_updated_fields
    users << owner unless user_ids.include?(owner.id)
    super
    if new_record?
      self.owner_id = owner&.id || User.current.id
    end
    generate_number
    ensure_token
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
  end

  def validates_configuration
    remove_attribute(:index_max_entries) if index_max_entries < DEFAULT_INDEX_MAX_ENTRIES
    validates_time_zone
    abort_if_has_errors
  end

  def default_time_zone
    nil
  end

  def time_zone_offset
    super || owner&.time_zone_offset
  end

  def notification_level_enum
    Setup::SystemNotification.type_enum
  end

  def label
    l = name.to_s
    unless User.current == owner
      l += " of #{owner.present? ? owner.label : Account.to_s + '#' + id.to_s}"
    end
    l
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

  def clean_up
    switch do
      Cenit::ApplicationId.where(:id.in => Setup::Application.all.collect(&:application_id_id)).delete_all
    end
    TaskToken.where(tenant_id: id).delete_all
    Setup::DelayedMessage.where(tenant_id: id).destroy_all
    each_tenant_collection(&:drop)
  end

  def notify(attrs)
    switch { Setup::SystemNotification.create_with(attrs.merge(skip_notification_level: true)) }
  end

  def notification_span_for(type)
    (owner && owner.notification_span_for(type)) ||
      Cenit[:"default_#{type}_notifications_span"] || 1.hour
  end

  def owner_switch(&block)
    current_user = User.current
    User.current = owner
    switch(&block)
  ensure
    User.current = current_user
  end

  def get_owner
    fail 'Illegal access to tenant owner' unless User.current_super_admin?
    owner
  end

  def for_create?
    @for_create || false
  end

  class << self

    def find_where(expression)
      scope = all(expression)
      unless User.current_super_admin?
        user_id = (user = User.current) && user.id
        member_account_ids = user && user.member_account_ids
        scope = scope.and({ '$or' => [
          { 'owner_id' => user_id },
          { '_id' => { '$in' => member_account_ids || [] } }
        ] })
      end
      scope
    end

    def find_all
      find_where({})
    end

    def notify(attrs)
      current && current.notify(attrs)
    end

    def current_id
      current&.id
    end

    def current_key
      (current&.number) || 'XXXXXXX'
    end

    def current_token
      (current&.token) || 'XXXXXXXXXXXXXXXX'
    end

    def new_for_create(params = {})
      account = new(params)
      account.instance_variable_set(:@for_create, true)
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

    def data_type_collection_name(data_type)
      tenant_collection_name(data_type.data_type_name)
    end

    def notification_span_for(type)
      ((current = self.current) && current.notification_span_for(type)) ||
        Cenit[:"default_#{type}_notifications_span"] || 1.hour
    end
  end
end

Tenant = Account