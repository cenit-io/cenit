require 'cenit/heroku_client'

class Account
  include Setup::CenitUnscoped
  include Cenit::MultiTenancy
  include NumberGenerator
  include TokenGenerator

  build_in_data_type.with(:name, :notification_level, :time_zone, :number, :authentication_token)
  build_in_data_type.protecting(:number, :authentication_token)
  build_in_data_type.and({
                           properties: {
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
                         }.stringify_keys)

  deny :all

  belongs_to :owner, class_name: User.to_s, inverse_of: :accounts
  has_and_belongs_to_many :users, class_name: User.to_s, inverse_of: nil

  field :name, type: String
  field :meta, type: Hash, default: {}

  field :notification_level, type: Symbol, default: :warning
  field :notifications_listed_at, type: DateTime

  field :time_zone, type: String, default: "#{Time.zone.name} | #{Time.zone.formatted_offset}"

  validates_presence_of :name, :notification_level, :time_zone
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
        self.name = n
      end
    else
      errors.add(:base, 'can not be created outside current user context')
    end
    errors.blank?
  end

  before_save :inspect_updated_fields, :init_heroku_db, :validates_configuration

  def account
    self
  end

  def user
    owner
  end

  def read_attribute(name)
    (!(value = super).nil? &&

      (new_record? || !self.class.data_type.protecting?(name) ||
        (current_user = User.try(:current)) && current_user.owns?(self)) &&

      value) || nil
  end

  def inspect_updated_fields
    users << owner unless user_ids.include?(owner.id)
    changed_attributes.keys.each do |attr|
      reset_attribute!(attr) unless %w(name notification_level time_zone).include?(attr)
    end unless new_record? || Account.current_super_admin?
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

  def time_zone_enum
    ActiveSupport::TimeZone.all.collect { |e| "#{e.name} | #{e.formatted_offset}" }
  end

  class << self

    def current_super_admin?
      current && current.super_admin?
    end

    def create_with_owner(params={})
      account = new(params)
      if (owner = account.owner)
        owner.roles << ::Role.where(name: :admin).first unless owner.roles.any? { |role| role.name.to_s == :admin.to_s }
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

    def data_type_collection_name(data_type)
      tenant_collection_name(data_type.data_type_name)
    end
  end
end
