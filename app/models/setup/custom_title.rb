module Setup
  module CustomTitle

    def title
      try(:name)
    end

    def scope_title
      nil
    end

    def custom_title
      if scoped_title = scope_title
        "#{scoped_title} | #{title}"
      else
        title
      end
    end

  end
end