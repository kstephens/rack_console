require 'spec_helper'
require 'rack_console/ansi2html'

module RackConsole
  describe Ansi2Html do
    subject { Ansi2Html }
    context "#convert" do
      subject do
        Ansi2Html.new
      end

      before :all do
        @@all_inputs = [ ]
        base_dir = File.expand_path('../../../..', __FILE__)
        @instance = Ansi2Html.new(nil)
        @html = File.open("#{base_dir}/tmp/test.html", 'w')
        File.write("#{base_dir}/tmp/ansi.css",
        File.read("#{base_dir}/lib/rack_console/template/css/ansi.css"))
        @html_body = ''
        @html.puts <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
        <link rel="stylesheet" href="ansi.css?">
        <style>
          .tt { font-family: monospace; }
          .xx { font-family: monospace; color: #ffffff; background-color: #000000;}
          .ansi-container {
            width: 100%;
            line-height: 1.2em;
            border-style: dotted;
            color: #c0c0c0;
            background-color: #202030;
            border-color: #c08080;
            border-width: 2px;
            padding: 1em;
          }
        </style>
        </head>
        <body style="color: #c0c0c0; background-color: #0c0c0c;">
        HTML
      end

      after :all do
        @html.puts <<-HTML
        #{@html_body}
        </body>
        </html>
        HTML
        @html.close rescue nil
      end

      def do_it input, expected = nil, *args
        @@all_inputs << input.dup
        binding.pry unless args.empty?

        actual = Ansi2Html.new.convert(input)
        @html_body << <<-HTML
          <table style="vertical-align: top;">
          <tr><td>input:</td><td><span class="tt">#{@instance.h_nbsp(input.inspect)}</span></td></tr>
          <tr><td>actual:</td><td>|<span class="tt">#{@instance.h_nbsp(actual)}</span>|</td></tr>
          <tr><td>rendered:</td><td><div class="ansi-container"><span class="xx ansi">--before-- #{actual} --after--</span></div></td></tr>
          </table>
          <hr/>
        HTML

        actual = subject.convert(input)
        if ENV['TEST_VERBOSE']
          puts "\n  ### input:     #{input.inspect}"
          puts "  ### rendered:  \"#{input}\"\e[0m =>"
          puts "  ### actual:    #{actual.inspect}"
          puts "  ### expected:  #{expected.inspect}" if expected
        end
        [ actual, expected ]
      end

      def self._ input, expected = nil
        it "converts ANSI #{input.inspect} to HTML #{expected.inspect}" do
          actual, expected = do_it(input, expected)
          if expected #  && false
            expect(actual) .to eq(expected), "actual: #{actual.inspect}"
          end
        end
      end

      ###################################################

      context "basic text" do
        _ "",
          ""
        _ "a",
        "a"
        _ "a b",
        "a&nbsp;b"
        _ "a b\nc",
        "a&nbsp;b<br/>c"
      end

      context "HTML text" do
        _ "HTML text: \01 ESC-HERE:\e <b>bold</b> \02 AFTER",
          "HTML&nbsp;text:&nbsp; ESC-HERE:\e &lt;b&gt;bold&lt;&#x2F;b&gt; &nbsp;AFTER"
      end

      context "raw characters" do
        _ "raw: \03 <b>bold</b> \04 AFTER",
          "raw:&nbsp; <b>bold</b> &nbsp;AFTER"
      end

      context "reset" do
        _ " ",
          "&nbsp;"
        _ "\e[0m(RESET)\e[0m",
          "(RESET)"
        _ "\e[1m(BOLD)\e[0m",
          "<span class=\"ansi-1\">(BOLD)</span>"
      end

      context "no reset" do
        _ "\e[1m(BOLD)\e[3m(AND-ITALIC)\e[22m-ITALIC",
          "<span class=\"ansi-1\">(BOLD)</span><span class=\"ansi-1 ansi-3\">(AND-ITALIC)</span><span class=\"ansi-3\">-ITALIC</span>"
        _ "\e[1;m(BOLD)",
          "<span class=\"ansi-1\">(BOLD)</span>"
      end

      context "text styles" do
        _ "\e[2;m(FAINT)\e[0m",
          "<span class=\"ansi-2\">(FAINT)</span>"
        _ "\e[3;m(ITALIC)\e[0m",
          "<span class=\"ansi-3\">(ITALIC)</span>"
        _ "\e[9;m(STRIKE)\e[0m",
          "<span class=\"ansi-9\">(STRIKE)</span>"
        _ "\e[1;m(BOLD)\e[3;m(AND-ITALIC)\e[0m",
          "<span class=\"ansi-1\">(BOLD)</span><span class=\"ansi-1 ansi-3\">(AND-ITALIC)</span>"
      end
      context "reverse" do
        _ "\e[7;m(REVERSE)\e[0m",
          "<span class=\"ansi-7\">(REVERSE)</span>"
          _ "\e[37;40;7;m(REVERSE)\e[0m",
          "<span class=\"ansi-7 ansi-37 ansi-40\">(REVERSE)</span>"
      end

      context "underline/overline" do
        _ "\e[4;m(UNDERLINE)\e[0m",
          "<span class=\"ansi-4\">(UNDERLINE)</span>"
        _ "\e[21;m(DOUBLE-UNDERLINE)\e[0m",
          "<span class=\"ansi-21\">(DOUBLE-UNDERLINE)</span>"
          _ "\e[4;58;2;255;55;55m(UNDERLINE-RED)\e[0m",
          "<span class=\"ansi-4\" style=\"text-decoration-color: #ff3737;\">(UNDERLINE-RED)</span>"

          _ "\e[53;m(OVERLINE)\e[0m",
          "<span class=\"ansi-53\">(OVERLINE)</span>"
      end

      context "framed" do
        _ "\e[51;36m(FRAMED-CYAN)\e[0m",
          "<span class=\"ansi-36 ansi-51\">(FRAMED-CYAN)</span>"
        _ "\e[52;31m(ENCIRCLED-RED)\e[0m",
          "<span class=\"ansi-31 ansi-52\">(ENCIRCLED-RED)</span>"
      end

      context "superscript/subscript" do
        _ "base\e[73m(i + SUPERSCRIPT)\e[0m",
          "base<span class=\"ansi-73\">(i&nbsp;+&nbsp;SUPERSCRIPT)</span>"
        _ "base\e[74m(j - SUBSCRIPT)\e[0m",
          "base<span class=\"ansi-74\">(j&nbsp;-&nbsp;SUBSCRIPT)</span>"
      end

      context "blink" do
        _ "\e[5;m(BLINK-SLOW)\e[0m",
          "<span class=\"ansi-5\">(BLINK-SLOW)</span>"
        _ "\e[6;31;100;m(BLINK-RAPID-RED-ON-GREY)\e[0m",
          "<span class=\"ansi-6 ansi-31 ansi-100\">(BLINK-RAPID-RED-ON-GREY)</span>"
      end

      context "proportional spacing" do
        _ "\e[26;m(PROPORTIONAL-SPACING)\e[0m",
          "<span class=\"ansi-26\">(PROPORTIONAL-SPACING)</span>"
      end

      context "basic color" do
          "<span class=\"ansi-1\">(BOLD)<span class=\"ansi-3\">(AND-ITALIC)</span></span>"
        _ "\e[31;m(RED)\e[0m",
          "<span class=\"ansi-31\">(RED)</span>"
        _ "\e[1;3;32;m(BOLD-ITALIC-GREEN)\e[0m",
          "<span class=\"ansi-1 ansi-3 ansi-32\">(BOLD-ITALIC-GREEN)</span>"
        _ "\e[1;34;45;m(BOLD-BLUE-ON-BRIGHT-MAGENTA)\e[0m",
          "<span class=\"ansi-1 ansi-34 ansi-45\">(BOLD-BLUE-ON-BRIGHT-MAGENTA)</span>"
      end

      context "background colors" do
        _ "\e[44;91;m(RED-BRIGHT-ON-BLUE)\e[0m",
          "<span class=\"ansi-44 ansi-91\">(RED-BRIGHT-ON-BLUE)</span>"
      end

      context "8-bit color" do
        context "foreground" do
          _ "\e[38;5;0m(000000)\e[0m",
            "<span style=\"color: #000000;\">(000000)</span>"

            _ "\e[38;5;8m(808080)\e[0m",
            "<span style=\"color: #808080;\">(808080)</span>"

            _ "\e[38;5;16m(000000)\e[0m",
            "<span style=\"color: #000000;\">(000000)</span>"

          _ "\e[38;5;25m(005faf)\e[0m",
            "<span style=\"color: #005faf;\">(005faf)</span>"
          _ "\e[38;5;94m(875f00)\e[0m",
            "<span style=\"color: #875f00;\">(875f00)</span>"
          _ "\e[38;5;187m(d7d7af)\e[0m",
            "<span style=\"color: #d7d7af;\">(d7d7af)</span>"

          _ "\e[38;5;232m(080808)\e[0m",
            "<span style=\"color: #080808;\">(080808)</span>"
          _ "\e[38;5;255m(eeeeee)\e[0m",
            "<span style=\"color: #eeeeee;\">(eeeeee)</span>"
        end
        context "background" do
          _ "\e[48;5;0m(000000)\e[0m",
            "<span style=\"background-color: #000000;\">(000000)</span>"

            _ "\e[48;5;8m(808080)\e[0m",
            "<span style=\"background-color: #808080;\">(808080)</span>"

            _ "\e[48;5;16m(000000)\e[0m",
            "<span style=\"background-color: #000000;\">(000000)</span>"

          _ "\e[48;5;25m(005faf)\e[0m",
            "<span style=\"background-color: #005faf;\">(005faf)</span>"
          _ "\e[48;5;94m(875f00)\e[0m",
            "<span style=\"background-color: #875f00;\">(875f00)</span>"
          _ "\e[48;5;187m(d7d7af)\e[0m",
            "<span style=\"background-color: #d7d7af;\">(d7d7af)</span>"

          _ "\e[48;5;232m(080808)\e[0m",
            "<span style=\"background-color: #080808;\">(080808)</span>"
          _ "\e[48;5;255m(eeeeee)\e[0m",
            "<span style=\"background-color: #eeeeee;\">(eeeeee)</span>"
        end
        context "complex" do
          _ "\e[38;5;0;48;5;7m(BLACK-ON-WHITE)\e[0m",
            "<span style=\"color: #000000; background-color: #c0c0c0;\">(BLACK-ON-WHITE)</span>"
        end
      end


      context "24-bit color" do
        _ "\e[38;2;16;200;255m(10c8ff)\e[0m",
          "<span style=\"color: #10c8ff;\">(10c8ff)</span>"
      end

      context "24-bit color codes and styles" do
        _ "\e[38;2;190;200;85;1;3m(COLOR-BOLD-ITALIC)\e[0m",
          "<span class=\"ansi-1 ansi-3\" style=\"color: #bec855;\">(COLOR-BOLD-ITALIC)</span>"
      end

      context "complex" do
        _ "\e[1;5;3;52;92;4;58;2;255;55;55;48;2;64;64;64;m(BLINK-BOLD-ITALIC-RED-UNDERLINED-ENCIRCLED-BRIGHT-GREEN-ON-GRAY)\e[0m",
        "<span class=\"ansi-1 ansi-3 ansi-4 ansi-5 ansi-52 ansi-92\" style=\"text-decoration-color: #ff3737; background-color: #404040;\">(BLINK-BOLD-ITALIC-RED-UNDERLINED-ENCIRCLED-BRIGHT-GREEN-ON-GRAY)</span>"
        _ "\e[1;5;4;52m(THIS)\e[22;25;73;3m(THAT)\e[0m",
          "<span class=\"ansi-1 ansi-4 ansi-5 ansi-52\">(THIS)</span><span class=\"ansi-3 ansi-4 ansi-52 ansi-73\">(THAT)</span>"
      end

      context "summary" do
        it "should work on all inputs" do
          lines = @@all_inputs.map do |input|
            "\001#{input.inspect}\002 =>\n#{input}\n"
          end * "\n"
          do_it("\n\n#{lines}\n\n")
        end
      end
    end
  end
end

