module NumberGenerator
  extend ActiveSupport::Concern

  NUMBER_LENGTH = 9
  NUMBER_LETTERS = false
  NUMBER_PREFIX = 'N'

  included do
    field :number, as: :key, type: String

    before_validation :ensure_number

    validates_uniqueness_of :number
  end

  def regenerate_number
    generate_number(force: true)
  end

  def ensure_number
    allow_generate = self.respond_to?(:owner) ? self.owner == User.current : true
    self[:number] = generate_number if new_record? || allow_generate && self[:number].blank?
  end

  def generate_number(options = {})
    options[:length] ||= NUMBER_LENGTH
    options[:letters] ||= NUMBER_LETTERS
    options[:prefix] ||= NUMBER_PREFIX

    possible = (0..9).to_a
    possible += ('A'..'Z').to_a if options[:letters]

    if self[:number].blank? || options[:force]
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

  module ClassMethods
    def by_number(number)
      where(number: number)
    end
  end
end
