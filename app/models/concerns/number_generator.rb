module NumberGenerator
  extend ActiveSupport::Concern

  NUMBER_LENGTH = 9
  NUMBER_LETTERS = false
  NUMBER_PREFIX = 'N'

  included do

    field :number, as: :key, type: String

    validates :number, uniqueness: true

    before_validation :generate_number

    before_save do
      errors.add(:number, "can't be blank") unless self[:number].present?
      errors.blank?
    end
  end

  def self.by_number(number)
    where(number: number)
  end

  def generate_number(options = {})
    options[:length] ||= NUMBER_LENGTH
    options[:letters] ||= NUMBER_LETTERS
    options[:prefix] ||= NUMBER_PREFIX

    possible = (0..9).to_a
    possible += ('A'..'Z').to_a if options[:letters]

    if self[:number].blank?
      self[:number] = loop do
        random = "#{options[:prefix]}#{(0...options[:length]).map { possible.shuffle.first }.join}"
        if self.class.where(number: random).exists?
          options[:length] += 1 if self.class.count > (10 ** options[:length] / 2)
        else
          break random
        end
      end
    end
  end
end
