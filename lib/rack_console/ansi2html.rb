# frozen_string_literal: true

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
      @out = out || ''.dup
      @close_tags = [ ]
      @attributes = { }
      @styles = { }
      @tag_cache = { }
      @tag_cache_size = 100
    end

    def convert str
      scan! str
      close_all_tags!
      @out
    end

    def << str
      @out << str
    end

    def raw! str
      self << str.to_s
    end

    def html! str
      self << Rack::Utils.escape_html(str.to_s)
    end

    def text! str
      return if str.empty?
      lines = str.split("\n", -1)
      last = lines.pop
      lines.each do | line |
        self << h_nbsp(line) unless line.empty?
        self << BR
      end
      self << h_nbsp(last) unless last.empty?
    end

    def comment! str
      self << "<!-- #{h(str)} -->"
    end

    def h_nbsp text
      h(text).gsub(' ', '&nbsp;')
    end

    def h text
      Rack::Utils.escape_html(text.to_s)
    end

    def scan! str
      until str.empty?
        case str
        when /\A\01([^\02]*?)\02/
          html!($1)
        when /\A\03([^\04]*?)\04/
          raw!($1)
        when /\A\e\[([\d;]+)m/
          codes = $1.split(';').reject(&:empty?).map(&:to_i)
          classes, styles = classes_styles_for_codes codes, @attributes, @styles.dup
          if classes != @classes || styles != @styles
            close_all_tags!
            unless classes.empty? && styles.empty?
              self << tag_cached(:span, classes, styles)
              @close_tags.push(SPAN_)
            end
            @classes, @styles = classes, styles
          end
        when /\A[^\01\03\e]+/
          text!($&)
        end
        str = $'
      end
      self
    end

    def tag_cached name, classes, styles
      @tag_cache.shift if @tag_cache.size > @tag_cache_size
      # @tag_cache_hits ||= Hash.new{|h, k| h[k] = 0}
      # @tag_cache_hits[[name, classes, styles]] += 1
      @tag_cache[[name, classes, styles]] ||=
        tag(name, classes, styles)
    end

    def tag name, classes, styles
      tag = "<#{name}".dup
      unless classes.empty?
        tag << ' class="'
        sep = Empty_String
        classes.each{|cls| tag << sep << "#{cls}" ; sep = ' '}
        tag << '"'
      end
      unless styles.empty?
        tag << ' style="'
        sep = Empty_String
        styles.each{|(k, v)| tag << sep << "#{k}: #{v};"; sep = ' ' }
        tag << '"'
      end
      tag << '>'
    end

    def close_all_tags!
      while tag = @close_tags.pop
        self << tag
      end
    end

    ######################################

    def classes_styles_for_codes escape_codes, attributes, styles
      codes = escape_codes.dup
      until codes.empty?
        code = codes.shift
        attributes.delete(CODE_CLEARS_ATTRIBUTE[code])
        case code
        when 0
          attributes.clear
          styles.clear
        when 38 # foreground: 8-bit LUT, 24-bit color
          styles.update(color_style(code, codes))
        when 48 # background: 8-bit LUT, 24-bit color
          styles.update(color_style(code, codes))
        when 58 # underline: 8-bit LUT, 24-bit color
          styles.update(color_style(code, codes))
        else
          if attribute = CODE_TO_ATTRIBUTE[code]
            attributes[attribute] = code
            styles.delete(ATTRIBUTE_CLEARS_STYLE[attribute])
          end
        end
      end
      classes = attributes.values.sort.map{|code| :"ansi-#{code}"}
      [ classes, styles ]
    end

    CODE_TO_ATTRIBUTE =
    {
      weight: [ 1, 2 ],
      italic: [ 3 ],
      underline: [ 4, 21, 53 ],
      blink: [ 5, 6 ],
      reverse: [ 7 ],
      conceal: [ 8 ],
      strikethrough: [ 9 ],
      font: (10 .. 20),
      proportional: [ 26 ],
      foreground: (30 .. 38).to_a + (90 .. 97).to_a,
      background: (40 .. 48).to_a + (100 .. 107).to_a,
      framed: [51, 52],
      overline: [ 53 ],
      underline_color: [ 58 ],
      subscript: [ 73, 74 ],
    }.flat_map do | attribute, codes |
      codes.map{|code| [ code, attribute ]}
    end.to_h

    ATTRIBUTE_CLEARS_STYLE = {
      foreground: :"color",
      background: :"background-color",
      underline_color: :"text-decoration-color",
    }

    CODE_CLEARS_ATTRIBUTE = {
      22 => :weight,
      23 => :underline,
      25 => :blink,
      27 => :reverse,
      28 => :conceal,
      20 => :strikethrough,
      39 => :foreground,
      49 => :background,
      50 => :proportional,
      54 => :framed,
      55 => :overline,
      59 => :underline_color,
      75 => :subscript,
    }
    # pp(CODE_TO_ATTRIBUTE: CODE_TO_ATTRIBUTE, CODE_CLEARS_ATTRIBUTE: CODE_CLEARS_ATTRIBUTE)

    ###################################

    def color_style code, codes
      color_space = codes.shift
      color = color_for_codes(color_space, codes)
      color and case code
      when 38
        { :"color" => color }
      when 48
        { :"background-color" => color }
      when 58
        { :"text-decoration-color" => color }
      else
        Empty_Hash
      end
    end

    def color_for_codes color_space, codes
      case color_space
      when 2 # R;G;B
        # https://en.wikipedia.org/wiki/ANSI_escape_code#24-bit
        "#%02x%02x%02x" % codes.shift(3)
      when 5 # 256-color mode
        # https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
        COLOR_8_LUT[codes.shift]
      end
    end

    COLOR_8_LUT =
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
    end.each{|s| s.freeze}.freeze

    Empty_String = ''.freeze
    Empty_Hash = {}.freeze
    SPAN_ = '</span>'.freeze
    BR = "<br/>".freeze

  end
end
