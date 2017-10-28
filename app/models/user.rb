require 'net/http'
require 'identicon'

class User
  include Mongoid::Document
  include Cenit::Oauth::User
  include Mongoid::Timestamps
  extend DeviseOverrides
  include CredentialsGenerator
  include FieldsInspection
  include RailsAdmin::Models::UserAdmin

  inspect_fields :name, :picture, :account_id, :api_account_id, :code_theme

  rolify

  has_many :accounts, class_name: Account.to_s, inverse_of: :owner
  has_and_belongs_to_many :member_accounts, class_name: Account.to_s, inverse_of: :users
  belongs_to :account, class_name: Account.to_s, inverse_of: :nil
  belongs_to :api_account, class_name: Account.to_s, inverse_of: :nil

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :rememberable

  devise :trackable, :validatable, :omniauthable, :database_authenticatable, :recoverable
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

  field :doorkeeper_uid, type: String
  field :doorkeeper_access_token, type: String
  field :doorkeeper_refresh_token, type: String
  field :doorkeeper_expires_at, type: Integer

  #Profile
  mount_uploader :picture, ImageUploader
  field :name, type: String

  #UI options
  field :code_theme, type: String

  validates_inclusion_of :code_theme, in: ->(user) { user.code_theme_enum }

  before_create do
    if self.class.empty?
      # The first User
      %w(super_admin installer).each do |role_name|
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

  before_save :ensure_token

  def all_accounts
    (accounts + member_accounts).uniq
  end

  def picture_url(size=50)
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

  def self.find_or_initialize_for_doorkeeper_oauth(oauth_data)
    user = User.where(email: oauth_data.info.email).first
    user ||= User.new(email: oauth_data.info.email, password: Devise.friendly_token[0, 20])
    user.confirmed_at ||= Time.now
    user.doorkeeper_uid = oauth_data.uid
    user
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session['devise.doorkeeper_data'] && session['devise.doorkeeper_data']['extra']['raw_info']
        user.email = data['email'] if user.email.blank?
      end
    end
  end

  def update_doorkeeper_credentials(oauth_data)
    self.doorkeeper_access_token = oauth_data.credentials.token
    self.doorkeeper_refresh_token = oauth_data.credentials.refresh_token
    self.doorkeeper_expires_at = oauth_data.credentials.expires_at
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
