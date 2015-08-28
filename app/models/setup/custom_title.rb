module Setup
  module CustomTitle

    def scope_title
      nil
    end

    def custom_title
      title = try(:title) || try(:name) || to_s
      if scoped_title = scope_title
        "#{scoped_title} | #{title}"
      else
        title
      end
    end

  end
end