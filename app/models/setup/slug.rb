module Setup
  module Slug
    extend ActiveSupport::Concern

    included do

      field :slug, type: String

      validates_length_of :slug, maximum: 255

      before_save :validate_slug
    end

    def validate_slug
      check_taken = true
      unless slug.present?
        candidate =
          if (candidate = slug_candidate).blank?
            'default'
          else
            candidate.squeeze(' ').tr(' ', '_')
          end
        i = candidate.length - 1
        while candidate.length.positive? && i == candidate.length - 1
          i -= 1 while i >= 0 && candidate[i] =~ /\A\.|[a-z]|[A-Z]|\d|_\Z/
          if i == candidate.length - 1
            candidate = candidate.to(i - 1)
            i = candidate.length - 1
          end
        end
        candidate = candidate.from(i + 1)
        candidate = 'default' if candidate.empty?
        if (candidate = candidate.split('.')).length > 1
          candidate.pop
          candidate = candidate.last
        else
          candidate = candidate[0]
        end
        candidate = candidate.underscore.gsub(/ +/, '_').downcase
        candidate = 'slug' if candidate.blank?
        i = 1
        while slug_taken?(candidate)
          candidate = candidate.gsub(/_\d*\Z/, '') + "_#{i += 1}"
        end
        self.slug = candidate
        check_taken = false
      end
      if slug =~ /\A([a-z]|_|\d)+\Z/
        errors.add(:slug, 'is taken') if check_taken && slug_taken?(slug)
      else
        errors.add(:slug, 'is not valid')
      end
      errors.blank?
    end

    protected

    def slug_candidate
      try(:name)
    end

    def slug_taken?(slug)
      self.class.where(slug: slug, :id.nin => [id]).present?
    end

  end
end
