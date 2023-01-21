require 'spec_helper'
require 'rack_console/ansi2html'

module RackConsole
  describe Ansi2Html do
    subject { Ansi2Html }
    context "#convert" do
      before :all do
        base_dir = File.expand_path('../../../..', __FILE__)
        @instance = Ansi2Html.new(nil)
        @html = File.open("#{base_dir}/tmp/test.html", 'w')
        File.write("#{base_dir}/tmp/ansi.css",
        File.read("#{base_dir}/lib/rack_console/template/css/ansi.css"))
        @html_body = ''
        @html.puts <<-HTML
        <html>
        <head>
        <link rel="stylesheet" href="ansi.css">
        <style>
          .tt { font-family: monospace; }
          .xx { font-family: monospace; background-color: #000000;}
          .ansi-container {
            border-style: dotted;
            color: #c0c0c0;
            background-color: #040808;
            border-color: #c08080;
            border-width: 2px;
            padding: 1em;
          }
        </style>
        </head>
        <body style="color: #c0c0c0; background-color: #0c0c0c; font: fixed-width;">
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

      def self._ str, html, before_after = true
        it "converts #{str.inspect} to #{html.inspect}" do
          if before_after
            str = "BEFORE-#{str}-AFTER"
            html = "BEFORE-#{html}-AFTER"
          end
          actual = subject.convert(str)
          if ENV['TEST_VERBOSE']
            puts "\n  ### escaped:   #{str.inspect} =>"
            puts "  ### rendered:  \"#{str}\"\e[0m =>"
            puts "  ### actual:    #{actual.inspect}"
            puts "  ### expected:  #{html.inspect}"
          end
          @html_body << <<-HTML
            <table>
            <tr><td>ansi:</td><td><span class="tt">#{@instance.h_nbsp(str.inspect)}</span></td></tr>
            <tr><td>html:</td><td><span class="tt">#{@instance.h_nbsp(actual)}</span></td></tr>
            <tr><td>rendered:</td><td><div class="ansi-container"><span class="xx ansi">#{actual}</span></div></td></tr>
            </table>
            <hr/>
          HTML
          expect(actual) .to eq html
        end
      end

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

      context "reset" do
        _ " ",
          "&nbsp;"
        _ "\e[0m(reset)\e[0m",
          "(reset)"
        _ "\e[1m(BOLD)\e[0m",
        "<span class=\"ansi-1\">(BOLD)</span>"
      end

      context "no reset" do
        _ "BEFORE-\e[1m(BOLD)\e[3m(AND-ITALIC)\e[22m-AFTER",
          "BEFORE-<span class=\"ansi-1\">(BOLD)<span class=\"ansi-3\">(AND-ITALIC)<span class=\"ansi-22\">-AFTER</span></span></span>",
          false
        _ "\e[1;m(BOLD)",
          "<span class=\"ansi-1\">(BOLD)</span>",
           false
      end

      context "text styles" do
        _ "\e[2;m(FAINT)\e[0m",
          "<span class=\"ansi-2\">(FAINT)</span>"
        _ "\e[3;m(ITALIC)\e[0m",
          "<span class=\"ansi-3\">(ITALIC)</span>"
        _ "\e[1;m(BOLD)\e[3;m(AND-ITALIC)\e[0m",
          "<span class=\"ansi-1\">(BOLD)<span class=\"ansi-3\">(AND-ITALIC)</span></span>"
      end

      context "framed" do
        _ "\e[51;36m(FRAMED)\e[0m",
        "<span class=\"ansi-51 ansi-36\">(FRAMED)</span>"
          _ "\e[52;36m(ENCIRCLED)\e[0m",
          "<span class=\"ansi-52 ansi-36\">(ENCIRCLED)</span>"
      end

      context "superscript/subscript" do
        _ "\e[73m(SUPERSCRIPT)\e[0m",
          "<span class=\"ansi-73\">(SUPERSCRIPT)</span>"
        _ "\e[74m(SUBSCRIPT)\e[0m",
        "<span class=\"ansi-74\">(SUBSCRIPT)</span>"
      end

      context "blink" do
        _ "\e[5;m(BLINK-SLOW)\e[0m",
          "<span class=\"ansi-5\">(BLINK-SLOW)</span>"
        _ "\e[6;31;100;m(BLINK-RAPID)\e[0m",
          "<span class=\"ansi-6 ansi-31 ansi-100\">(BLINK-RAPID)</span>"
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
        _ "\e[38;5;0m(000000)\e[0m",
        "<span class=\"ansi-38\" style=\"color: #000000;\">(000000)</span>"
        _ "\e[38;5;0;48;5;7m(white-on-black)\e[0m",
        "<span class=\"ansi-38 ansi-48\" style=\"color: #000000; background-color: #c0c0c0;\">(white-on-black)</span>"

        _ "\e[38;5;8m(808080)\e[0m",
        "<span class=\"ansi-38\" style=\"color: #808080;\">(808080)</span>"

        _ "\e[38;5;16m(text)\e[0m",
        "<span class=\"ansi-38\" style=\"color: #000000;\">(text)</span>"
        _ "\e[38;5;25m(text)\e[0m",
        "<span class=\"ansi-38\" style=\"color: #005faf;\">(text)</span>"
        _ "\e[38;5;94m(text)\e[0m",
        "<span class=\"ansi-38\" style=\"color: #875f00;\">(text)</span>"
        _ "\e[38;5;187m(text)\e[0m",
        "<span class=\"ansi-38\" style=\"color: #d7d7af;\">(text)</span>"

        _ "\e[38;5;232m(text)\e[0m",
        "<span class=\"ansi-38\" style=\"color: #080808;\">(text)</span>"
        _ "\e[38;5;255m(text)\e[0m",
        "<span class=\"ansi-38\" style=\"color: #eeeeee;\">(text)</span>"
      end

      context "24-bit color" do
        _ "\e[38;2;16;200;255m(text)\e[0m",
        "<span class=\"ansi-38\" style=\"color: #10c8ff;\">(text)</span>"
      end

      context "24-bit color codes and styles" do
        _ "\e[38;2;190;200;85;1;3m(COLOR-BOLD-ITALIC)\e[0m",
        "<span class=\"ansi-38 ansi-1 ansi-3\" style=\"color: #bec855;\">(COLOR-BOLD-ITALIC)</span>"
      end

    end
  end
end

