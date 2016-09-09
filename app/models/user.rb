require 'net/http'
require 'identicon'

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  extend DeviseOverrides
  include NumberGenerator
  include TokenGenerator
  rolify

  has_many :accounts, class_name: Account.to_s, inverse_of: :owner
  belongs_to :account, class_name: Account.to_s, inverse_of: :nil
  belongs_to :api_account, class_name: Account.to_s, inverse_of: :nil

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :rememberable

  devise :trackable, :validatable, :omniauthable, :database_authenticatable, :recoverable
  devise :registerable unless ENV['UNABLE_REGISTERABLE'].to_b
  devise :confirmable unless ENV['UNABLE_CONFIRMABLE'].to_b

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

  field :name, type: String
  mount_uploader :picture, ImageUploader

  before_create do
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

  before_save :ensure_token, :inspect_updated_fields

  def user
    self
  end

  def owns?(account)
    !account.nil? && account.owner_id == id
  end

  def account_ids
    accounts.collect(&:id)
  end

  def label
    if name.present?
      "#{name} (#{email})"
    else
      email
    end
  end

  def inspect_updated_fields
    changed_attributes.keys.each do |attr|
      reset_attribute!(attr) unless %w(name picture account_id api_account_id).include?(attr)
    end unless core_handling? || new_record? || (Account.current && Account.current_super_admin?)
    errors.blank?
  end

  def core_handling(*arg)
    @core_handling = arg[0].to_s.to_b
  end

  def core_handling?
    @core_handling
  end

  def confirm(args={})
    core_handling true
    super
  end

  def self.find_or_initialize_for_doorkeeper_oauth(oauth_data)
    user = User.where(email: oauth_data.info.email).first
    user ||= User.new(email: oauth_data.info.email, password: Devise.friendly_token[0, 20])
    user.confirmed_at ||= Time.now
    user.doorkeeper_uid = oauth_data.uid
    user.core_handling true
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

  def identicon(size=50)
    Identicon.data_url_for email.downcase, size
  end

  def gravatar_or_identicon_url(size=50)
    if gravatar()
      "//gravatar.com/avatar/#{Digest::MD5.hexdigest email}?s=#{size}"
    else
      identicon size
    end
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
  end

end
