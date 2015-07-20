module RackConsole
  class Ansi2Html
    def initialize
      @tag_b = { }
      @tag_e = { }
    end

    def convert str, out = nil
      @str = str.dup
      @out = out || ''
      @tags = [ ]
      @out << %Q{<div class="ansi">}
      scan!
      tag_pop!
      @out << %Q{</div>}
      @out
    end

    def scan!
      until @str.empty?
        case @str
        when /\A[^\e]+/
          text($&)
        when /\A\e\[([\d;]+)m/
          codes = $1.split(';').reject(&:empty?).map(&:to_i)
          codes.each do | code |
            cls = CLASS_FOR_CODE[code]
            tag(:span, cls) unless cls.nil?
          end
        when /\A.*/
          text($&)
        end
        @str = $'
      end
      self
    end

    def tag name, cls
      if cls
        tag_b =
          @tag_b[[name, cls]] ||= %Q{<#{name} class="#{cls}">}.freeze
        tag_e =
          @tag_e[name] ||= %Q{</#{name}>}.freeze
        @tags << [ tag_b, tag_e ]
        @out << tag_b
      else
        tag_pop!
      end
    end

    def tag_pop!
      while tag_be = @tags.pop
        @out << tag_be[1]
      end
    end

    def text str
      lines = str.split("\n", 99999)
      last = lines.pop
      lines.each do | line |
        @out << h(line)
        @out << BR
      end
      @out << h(last)
    end

    def h(text)
      Rack::Utils.escape_html(text.to_s).gsub(' ', '&nbsp;')
    end

    SPAN_END = "</span>".freeze
    BR = "<br/>".freeze

    # https://en.wikipedia.org/wiki/ANSI_escape_code
    CLASS_FOR_CODE = {
      0 => false,
      1 => :bold,
      2 => :faint,
      3 => :italic,
      4 => :underline,
      30 => :black,
      31 => :red,
      32 => :green,
      33 => :yellow,
      34 => :blue,
      35 => :magenta,
      36 => :cyan,
      37 => :white,
      40 => :bg_black,
      41 => :bg_red,
      42 => :bg_green,
      43 => :bg_yellow,
      44 => :bg_blue,
      45 => :bg_magenta,
      46 => :bg_cyan,
      47 => :bg_white,
    }
  end
end
