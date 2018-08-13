require 'net/http'
require 'identicon'
require 'mongoid_userstamp'

class User
  include Setup::CenitUnscoped
  include Cenit::Oauth::User
  extend DeviseOverrides
  include CredentialsGenerator
  include FieldsInspection
  include TimeZoneAware
  include RailsAdmin::Models::UserAdmin


  inspect_fields :name, :picture, :account_id, :api_account_id, :code_theme, :time_zone

  rolify

  build_in_data_type.with(:email, :name, :account)

  deny :all

  has_many :accounts, class_name: Account.to_s, inverse_of: :owner
  has_and_belongs_to_many :member_accounts, class_name: Account.to_s, inverse_of: :users
  belongs_to :account, class_name: Account.to_s, inverse_of: nil
  belongs_to :api_account, class_name: Account.to_s, inverse_of: nil

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :rememberable

  devise :trackable, :validatable, :database_authenticatable, :recoverable
  devise :registerable unless ENV['UNABLE_REGISTERABLE'].to_b
  devise :confirmable if ENV.has_key?('UNABLE_CONFIRMABLE') && !ENV['UNABLE_CONFIRMABLE'].to_b

  # Database authenticatable
  field :email, type: String, default: ''
  field :encrypted_password, type: String, default: ''

  ## Recoverable
  field :reset_password_token, type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Trackable
  field :sign_in_count, type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at, type: Time
  field :confirmed_at, type: Time
  field :confirmation_sent_at, type: Time
  field :confirmation_token, type: String
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip, type: String
  field :unconfirmed_email, type: String

  #Profile
  mount_uploader :picture, ImageUploader
  field :name, type: String

  #UI options
  field :code_theme, type: String

  field :super_admin_enabled, type: Boolean, default: -> { has_role?(:super_admin) }

  def inspecting_fields
    super + (has_role?(:super_admin) ? [:super_admin_enabled] : [])
  end

  def check_attributes
    remove_attribute(:super_admin_enabled) unless has_role?(:super_admin)
    true
  end

  validates_inclusion_of :code_theme, in: ->(user) { user.code_theme_enum }

  before_create do
    if self.class.empty?
      # The first User
      %w(super_admin installer cross_shared).each do |role_name|
        unless roles.any? { |role| role.name.to_s == role_name }
          roles << ::Role.find_or_create_by(name: role_name)
        end
      end
    end
    created_account = nil
    self.account ||= Account.current || (created_account = Account.create_with_owner(owner: self))
    accounts << created_account if created_account
    unless owns?(account)
      errors.add(:account, 'is sealed and can not be inspected') if account && account.sealed?
    end
    unless owns?(api_account)
      self.api_account = owns?(account) ? account : accounts.first
    end
    errors.blank?
  end

  before_save :check_attributes, :ensure_token, :validates_time_zone!, :check_account

  def check_account
    unless super_admin? || accounts.where(id: account_id).exists? || member_account_ids.include?(account_id)
      errors.add(:account, 'is not valid')
    end
    errors.blank?
  end

  def all_accounts
    (accounts + member_accounts).uniq
  end

  def picture_url(size = 50)
    custom_picture_url(size) || gravatar_or_identicon_url(size)
  end

  def custom_picture_url(size)
    picture && picture.url
  end

  def code_theme_enum
    [nil, ''] +
      %w(3024-day 3024-night abcdef ambiance-mobile ambiance base16-dark base16-light bespin blackboard cobalt colorforth dracula eclipse elegant erlang-dark hopscotch icecoder isotope lesser-dark liquibyte material mbo mdn-like midnight monokai neat neo night panda-syntax paraiso-dark paraiso-light pastel-on-dark railscasts rubyblue seti solarized the-matrix tomorrow-night-bright tomorrow-night-eighties ttcn twilight vibrant-ink xq-dark xq-light yeti zenburn)
  end

  def user
    self
  end

  def owns?(account)
    !account.nil? && account.owner_id == id
  end

  def member?(account)
    !account.nil? && account.users.map(&:id).include?(id)
  end

  def account_ids #TODO look for usages and try to optimize
    accounts.collect(&:id)
  end

  def label
    if name.present?
      "#{name} (#{email})"
    else
      email
    end
  end

  def method_missing(symbol, *args)
    if (match = symbol.to_s.match(/(.+)\?/))
      has_role?(match[1].to_sym)
    else
      super
    end
  end

  def admin?
    has_role?(:admin) || has_role?(:super_admin)
  end

  def super_admin?
    has_role?(:super_admin) && super_admin_enabled
  end

  def notification_span_for(type)
    type = type.to_s.to_sym
    unless @notification_spans
      @notification_spans = {}
      regex = Regexp.new("\\A(#{Setup::SystemNotification.type_enum.join('|')})_notifications_span\\Z")
      roles.each do |role|
        next unless (metadata = role.metadata).is_a?(Hash)
        metadata.each do |key, value|
          next unless (match = key.to_s.match(regex))
          t = match[1].to_sym
          @notification_spans[t] = [@notification_spans[t] || 0, value.to_i].max
        end
      end
    end
    @notification_spans[type]
  end

  class << self

    def method_missing(symbol, *args)
      if (match = symbol.to_s.match(/\Acurrent_(.+)\?/))
        current && current.send("#{match[1]}?")
      else
        super
      end
    end

    def super_admin
      all.select { |u| u.has_role? :super_admin }
    end

    def current_number
      (current && current.number) || 'XXXXXXX'
    end

    def current_token
      (current && current.token) || 'XXXXXXXXXXXXXXXX'
    end

    def current_id
      current && current.id
    end
  end

end
