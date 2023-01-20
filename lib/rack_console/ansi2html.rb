require 'rack/utils'

module RackConsole
  # TODO: Move to devdriven-ruby
  # Spans delimited by \01...\02 are considered
  # to be raw HTML.
  class Ansi2Html
    @@tag_cache = { }

    def self.convert str, out = nil
      new(out).convert(str)
    end

    def initialize out = nil
      @out  = out || ''.dup
      @tags = [ ]
    end

    def convert str
      @str = str.dup
      self << %Q{<div class="ansi">}
      scan!
      tag_pop!
      self << %Q{</div>}
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
          until codes.empty?
            case cls = CLASS_FOR_CODE[codes.shift]
            when nil
            when :foreground_color, :background_color
              tag_color(cls, codes)
            else
              tag(:span, cls)
            end
          end
        when /\A.+/
          text($&)
        end
        @str = $'
      end
      self
    end

    def tag_color cls, codes
      case color_space = codes.shift
      when 2 # R:G:B
        # https://en.wikipedia.org/wiki/ANSI_escape_code#24-bit
        color = "#%02x%02x%02x" % codes.shift(3)
      when 5 # 256-color mode
        # https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
        index = codes.shift
        color = COLOR_8[index] ||= color_8_bit(index)
      else
        codes.clear # EAT
      end
      case cls
      when :foreground_color
        style = "color: #{color};"
      when :background_color
        style = "background-color: #{color};"
      end
      tag(:span, cls, style)
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

    COLOR_8 = [ nil ] * 256 # Cache
    COLOR_8_LOOKUP = %w{#000000 #800000 #008000 #808000 #000080 #800080 #008080 #c0c0c0
                        #808080 #ff0000 #00ff00 #ffff00 #0000ff #ff00ff #00ffff #ffffff}
    COLOR_8_RAMP_6 = %w{00 5f 87 af d7 ff}
    COLOR_8_GRAY = %w{#080808 #121212 #1c1c1c #262626 #303030 #3a3a3a #444444 #4e4e4e
                      #585858 #626262 #6c6c6c #767676 #808080 #8a8a8a #949494 #9e9e9e
                      #a8a8a8 #b2b2b2 #bcbcbc #c6c6c6 #d0d0d0 #dadada #e4e4e4 #eeeeee}

    def tag name, cls, style = nil
      if cls
        if style
          tag_be = [
            %Q{<#{name} class="#{cls}" style="#{style}">}.freeze,
            %Q{</#{name}>}.freeze,
          ].freeze
        else
          tag_be =
            (@@tag_cache[name] ||= { })[cls] ||=
            [
              %Q{<#{name} class="#{cls}">}.freeze,
              %Q{</#{name}>}.freeze,
            ].freeze
        end
        @tags << tag_be
        self  << tag_be[0]
      else
        tag_pop!
      end
    end

    def tag_pop!
      while tag_be = @tags.pop
        self << tag_be[1]
      end
    end

    def text str
      return if str.empty?
      lines = str.split("\n", -1)
      last = lines.pop
      lines.each do | line |
        self << h(line) unless line.empty?
        self << BR
      end
      self << h(last) unless last.empty?
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
      5 => :slow_blink,
      6 => :rapid_blink,
      7 => :reverse,
      8 => :conceal,
      9 => :crossed_out,
      10 => :primary_font,
      21 => :double_underline,
      28 => :reveal,
      29 => :not_crossed_out,
      51 => :framed,
      53 => :overlined,
      73 => :superscript,
      74 => :subscript,
      30 => :black,
      31 => :red,
      32 => :green,
      33 => :yellow,
      34 => :blue,
      35 => :magenta,
      36 => :cyan,
      37 => :white,

      90 => :bright_black,
      91 => :bright_red,
      92 => :bright_green,
      93 => :bright_yellow,
      94 => :bright_blue,
      95 => :bright_magenta,
      96 => :bright_cyan,
      97 => :bright_white,

      40 => :bg_black,
      41 => :bg_red,
      42 => :bg_green,
      43 => :bg_yellow,
      44 => :bg_blue,
      45 => :bg_magenta,
      46 => :bg_cyan,
      47 => :bg_white,

      100 => :bg_bright_black,
      101 => :bg_bright_red,
      102 => :bg_bright_green,
      103 => :bg_bright_yellow,
      104 => :bg_bright_blue,
      105 => :bg_bright_magenta,
      106 => :bg_bright_cyan,
      107 => :bg_bright_white,

      38 => :foreground_color,
      48 => :background_color,
    }
  end
end
