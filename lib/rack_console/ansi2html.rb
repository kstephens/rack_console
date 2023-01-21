require 'rack/utils'

module RackConsole
  # TODO: Move to devdriven-ruby
  # Spans delimited by \01...\02 are considered
  # to be raw HTML.
  class Ansi2Html
    def self.convert str, out = nil
      new(out).convert(str)
    end

    def initialize out = nil
      @out  = out || ''.dup
      @close_tags = [ ]
    end

    def convert str
      @str = str.dup
      scan!
      close_all_tags!
      @out
    end

    def << str
      @out << str
    end

    def scan!
      until @str.empty?
        case @str
        when /\A\01([^\02]*)\02/
          html($1)
        when /\A[^\e]+/
          text($&)
        when /\A\e\[([\d;]+)m/
          codes = $1.split(';').reject(&:empty?).map(&:to_i)
          classes = [ ]
          styles = [ ]
          until codes.empty?
            case code = codes.shift
            when nil
              comment("ansi2html : unknown code : #{code}")
            when 0
              close_all_tags!
            when 38, 48 # 8-bit, 24-bit color
              classes << :"ansi-#{code}"
              styles << color_style(code, codes)
            else
              classes << :"ansi-#{code}"
            end
          end
          span(classes, styles)
        when /\A.+/
          text($&)
        end
        @str = $'
      end
      self
    end

    def color_style code, codes
      case color_space = codes.shift
      when 2 # R;G;B
        # https://en.wikipedia.org/wiki/ANSI_escape_code#24-bit
        color = "#%02x%02x%02x" % codes.shift(3)
      when 5 # 256-color mode
        # https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
        color = COLOR_8[codes.shift]
      end
      raise unless color
      case code
      when 38
        "color: #{color}"
      when 48
        "background-color: #{color}"
      else
        # "ansi-color-style-space: #{cls}"
      end
    end

    def color_8_bit index
      case index
      when 0...16
        COLOR_8_LOOKUP[index]
      when 16...232
        index -= 16
        b = index % 6; index /= 6
        g = index % 6; index /= 6
        r = index % 6
        "#" + COLOR_8_RAMP_6[r] + COLOR_8_RAMP_6[g] + COLOR_8_RAMP_6[b]
      else
        COLOR_8_GRAY[index - 232]
      end
    end

    COLOR_8 =
    begin
      ramp_6 = %w{00 5f 87 af d7 ff}
      %w{
        #000000 #800000 #008000 #808000 #000080 #800080 #008080 #c0c0c0
        #808080 #ff0000 #00ff00 #ffff00 #0000ff #ff00ff #00ffff #ffffff
      } +
      ramp_6.flat_map{|r| ramp_6.flat_map{|g| ramp_6.map{|b| "##{r}#{g}#{b}".freeze }}} +
      %w{
      #080808 #121212 #1c1c1c #262626 #303030 #3a3a3a #444444 #4e4e4e
      #585858 #626262 #6c6c6c #767676 #808080 #8a8a8a #949494 #9e9e9e
      #a8a8a8 #b2b2b2 #bcbcbc #c6c6c6 #d0d0d0 #dadada #e4e4e4 #eeeeee
    }
    end
    raise unless COLOR_8.size == 256

    def span classes, styles
      attrs = [ ]
      (attrs << "class=#{classes.join(' ').inspect}") unless classes.empty?
      (attrs << "style=#{(styles.join('; ') + ';').inspect}") unless styles.empty?
      return if attrs.empty?
      self << "<span #{attrs.join(' ')}>".freeze
      @close_tags.push(SPAN_)
      self
    end

    def close_all_tags!
      while tag = @close_tags.pop
        self << tag
      end
    end

    def html str
      self << Rack::Utils.escape_html(text.to_s)
    end

    def text str
      return if str.empty?
      lines = str.split("\n", -1)
      last = lines.pop
      lines.each do | line |
        self << h_nbsp(line) unless line.empty?
        self << BR
      end
      self << h_nbsp(last) unless last.empty?
    end

    def comment str
      self << "<!-- #{h(str)} -->"
    end

    def h_nbsp text
      h(text).gsub(' ', '&nbsp;')
    end

    def h text
      Rack::Utils.escape_html(text.to_s)
    end


    SPAN_ = '</span>'.freeze
    BR = "<br/>".freeze

  end
end
