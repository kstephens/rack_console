require 'spec_helper'
require 'rack_console/ansi2html'

module RackConsole
  describe Ansi2Html do
    subject { Ansi2Html }
    context "#convert" do
      def self._ str, html
        it "converts #{str.inspect} to #{html.inspect}" do
          expect(subject.convert(str)) .to eq html
        end
      end

      context "basic text" do
        _ "",
          "<div class=\"ansi\"></div>"
        _ "a",
        "<div class=\"ansi\">a</div>"
        _ "a b",
        "<div class=\"ansi\">a&nbsp;b</div>"
        _ "a b\nc",
        "<div class=\"ansi\">a&nbsp;b<br/>c</div>"
      end

      context "escape sequences" do
        _ "\e[0m text ",
          "<div class=\"ansi\">&nbsp;text&nbsp;</div>"
        _ "\e[1;m text ",
          "<div class=\"ansi\"><span class=\"bold\">&nbsp;text&nbsp;</span></div>"
        _ "\e[2;m text \e[0m",
          "<div class=\"ansi\"><span class=\"faint\">&nbsp;text&nbsp;</span></div>"
        _ "\e[2;m text \e[0m",
          "<div class=\"ansi\"><span class=\"faint\">&nbsp;text&nbsp;</span></div>"
        _ "\e[31;m text \e[0m",
          "<div class=\"ansi\"><span class=\"red\">&nbsp;text&nbsp;</span></div>"
        _ "\e[1;32;m text \e[0m",
          "<div class=\"ansi\"><span class=\"bold\"><span class=\"green\">&nbsp;text&nbsp;</span></span></div>"
        _ "\e[33;45;m text \e[0m",
          "<div class=\"ansi\"><span class=\"yellow\"><span class=\"bg_magenta\">&nbsp;text&nbsp;</span></span></div>"
      end
    end
  end
end

