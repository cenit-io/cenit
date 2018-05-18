module Setup
  class ErbTemplate < Template
    include BulkableTransformation
    include SnippetCodeTemplate
    include RailsAdmin::Models::Setup::ErbTemplateAdmin

    build_in_data_type.referenced_by(:namespace, :name)

    def code_extension
      if (ext = super).present?
        "#{ext}.erb"
      else
        'erb'
      end
    end

    def execute(options)
      code = preprocess_erb(options[:code], options)

      if options[:control]
        options[:control].view ||= ActionView::Base.new(nil, {}, options[:control].try(:controller))
      end
      av = options[:control].try(:view) || ActionView::Base.new

      av.render inline: code, handlers: 'erb', locals: options
    end

    def preprocess_erb(code, options)
      return code if Capataz.disable?
      pattern = /(<%=?)(.*?)(%>)/m
      rb = []
      gs = Gensym.new
      marks = []
      res = code.gsub(pattern) do
        match_1 = Regexp.last_match[1]
        match_2 = Regexp.last_match[2]
        match_3 = Regexp.last_match[3]
        mark = gs.gen
        marks << mark.to_sym
        rb << match_2.strip.gsub(/\n/, ';').squeeze(';') + " ; #{mark}"
        match_1 + mark + match_3
      end
      rb_src = rb.join("\n")
      lcls = options.keys.to_a + marks
      rw = Capataz.rewrite(rb_src, locals: lcls)
      rw = rw.split(/\n/)[(lcls.length)..-1]

      marks.to_enum.with_index.reverse_each do |mark, i|
        res = res.gsub(mark.to_s, rw[i][0..(-(mark.to_s.length + 3))])
      end

      res
    end

    class Gensym
      def initialize
        @val = 1
      end

      def gen
        r = "____#{@val}"
        @val += 1
        r
      end
    end
  end
end
