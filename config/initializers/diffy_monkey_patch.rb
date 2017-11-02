require 'diffy/html_formatter'

module Diffy
  class HtmlFormatter

    def wrap_lines(lines)
      min_count_collapse = 3
      if lines.empty?
        %'<div class="diff"></div>'
      else
        all_lines = []
        unchanged_lines = []
        lines.each_with_index do |l, idx|
          if is_unchanged l
            unchanged_lines << l
          else
            if (unchanged_lines.length > min_count_collapse)
              all_lines.concat(wrapped_collapse(unchanged_lines))
              unchanged_lines= []
            else
              if (unchanged_lines.length > 0)
                all_lines.concat(unchanged_lines)
                unchanged_lines= []
              end
            end
            all_lines << l
          end
        end
        if (unchained_count = unchanged_lines.length) > 0
          if unchained_count > min_count_collapse
            all_lines.concat(wrapped_collapse(unchanged_lines))
          else
            all_lines.concat(unchanged_lines)
          end
        end
        %'<div class="diff">\n  <ul type="ordered">\n#{all_lines.join("\n")}\n  </ul>\n</div>\n'
      end
    end

    def is_unchanged l
      /<li class="unchanged"><span>/.match(l.lstrip)
    end

    def line_code l
      /<li class="(.*)"><span>(.*)<\/span><\/li>/.match(l.lstrip)[2]
    end

    def wrapped_collapse lines
      [%(<li class="wrapped">
          <a class="expand_collapse"></a>
          <span class="count-lines">#{lines.length} lines unchanged </span>
          <span class="first_line">#{line_code lines.shift}</span>
          <ul>
            #{lines.join("\n")}
          </ul>
       </li>)]
    end

  end
end
