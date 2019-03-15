module Setup
  module CustomTitle
    def scope_title
      nil
    end

    def custom_title(separator = '|')
      title = try(:title) || try(:name) || to_s
      if (scoped_title = scope_title).present?
        title = "#{scoped_title} #{separator} #{title}"
      end
      if (origin = try(:origin)) && origin != :default
        title = "#{title} [#{I18n.t("admin.origin.#{origin}")}]"
      end
      title
    end

  end
end
