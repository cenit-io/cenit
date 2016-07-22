require 'net/http'
require 'identicon'

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  extend DeviseOverrides
  include NumberGenerator
  rolify

  belongs_to :account, inverse_of: :users, class_name: Account.to_s
  scope :by_account, -> { where(account: Account.current) }

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :rememberable

  devise :trackable, :validatable, :omniauthable, :database_authenticatable, :recoverable
  devise :registerable unless (ENV['UNABLE_REGISTERABLE'] || false).to_b
  devise :confirmable unless (ENV['UNABLE_CONFIRMABLE'] || true).to_b

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
  field :authentication_token, as: :token, type: String
  field :number, as: :key, type: String
  field :unique_key, type: String
  field :unconfirmed_email, type: String

  field :doorkeeper_uid, type: String
  field :doorkeeper_access_token, type: String
  field :doorkeeper_refresh_token, type: String
  field :doorkeeper_expires_at, type: Integer

  field :name, type: String
  mount_uploader :picture, ImageUploader

  before_save :ensure_token
  before_create { self.account ||= Account.current || Account.create_with_owner(owner: self) }

  validates_uniqueness_of :token
  before_save :ensure_token, :inspect_updated_fields

  def label
    if name.present?
      "#{name} (#{email})"
    else
      email
    end
  end

  def inspect_updated_fields
    changed_attributes.keys.each do |attr|
      reset_attribute!(attr) unless %w(name picture).include?(attr)
    end unless core_handling? || new_record? || (Account.current && Account.current_super_admin?)
    true
  end

  def core_handling=(arg)
    @core_handling = arg.present?
  end

  def core_handling?
    @core_handling
  end

  def self.find_or_initialize_for_doorkeeper_oauth(oauth_data)
    user = User.where(email: oauth_data.info.email).first
    user ||= User.new(email: oauth_data.info.email, password: Devise.friendly_token[0, 20])
    user.confirmed_at ||= Time.now
    user.doorkeeper_uid = oauth_data.uid
    user.core_handling = true
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

  def ensure_token
    self.token ||= generate_token
    md5 = Digest::MD5.new
    md5 << key
    md5 << token
    self.unique_key = md5.hexdigest
  end

  def generate_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(token: token).first
    end
  end

  def admin?
    has_role?(:admin) || has_role?(:super_admin)
  end

  def super_admin?
    has_role?(:super_admin)
  end

  def gravatar()
    gravatar_check = "//gravatar.com/avatar/#{Digest::MD5.hexdigest(email.downcase)}.png?d=404"
    uri = URI.parse(gravatar_check)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new("/avatar/#{Digest::MD5.hexdigest(email.downcase)}.png?d=404")
    response = http.request(request)
    response.code.to_i < 400 # from d=404 parameter
  rescue
    false
  end

  def identicon(size=60)
    Identicon.data_url_for email.downcase, size
  end

  def gravatar_or_identicon_url(size=60)
    if gravatar()
      "//gravatar.com/avatar/#{Digest::MD5.hexdigest email}?s=#{size}"
    else
      identicon size
    end
  end

  class << self
    def current_admin?
      current && current.admin?
    end

    def current_super_admin?
      current && current.super_admin?
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
  end

end
