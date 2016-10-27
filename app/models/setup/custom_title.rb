module Setup
  module CustomTitle

    def scope_title
      nil
    end

    def custom_title
      title = try(:title) || try(:name) || to_s
      if (scoped_title = scope_title).present?
        title = "#{scoped_title} | #{title}"
      end
      if (origin = try(:origin)) && origin != :default
        title = "#{title} [#{origin}]"
      end
      title
    end

  end
end