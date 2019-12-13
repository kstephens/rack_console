require 'rack/utils'

module RackConsole
  # Spans delimited by \01...\02 are considered
  # to be raw HTML.
  class Ansi2Html
    @@tag_cache = { }

    def self.convert str, out = nil
      new(out).convert(str)
    end

    def initialize out = nil
      @out  = out || ''
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
          codes.each do | code |
            cls = CLASS_FOR_CODE[code]
            tag(:span, cls) unless cls.nil?
          end
        when /\A.+/
          text($&)
        end
        @str = $'
      end
      self
    end

    def tag name, cls
      if cls
        tag_be =
          (@@tag_cache[name] ||= { })[cls] ||=
          [
          %Q{<#{name} class="#{cls}">}.freeze,
          %Q{</#{name}>}.freeze,
          ].freeze
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
      lines = str.split("\n", 99999)
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
