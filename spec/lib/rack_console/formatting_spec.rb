# encoding: UTF-8
# -*- coding: utf-8 -*-
require 'spec_helper'
require 'rack_console/formatting'

module RackConsole
  describe Formatting do
    subject do
      obj = OpenStruct.new(config: config)
      def obj.url_root(x)
        "/#{x}"
      end
      obj.extend(Formatting)
    end
    let(:config) { { } }
    context "#format_object" do
      context "Module" do
        it "returns HTML" do
          expect(subject.format_object(Formatting)).to eq "<span class=\"module_name\"><a href='//module/RackConsole' class='module_name'><span class=\"module_name\">RackConsole</span></a><a href='//module/RackConsole::Formatting' class='module_name'><span class=\"module_name\">::Formatting</span></a></span>"
        end
      end
      context "Fixnum" do
        it "returns HTML" do
          expect(subject.format_object(1234)).to eq "<pre>1234</pre>"
          expect(subject.format_object(1234, :inline)).to eq %Q{<span class="literal">1234</span>}
        end
      end
      context "Symbol" do
        it "returns HTML" do
          expect(subject.format_object(:foo)).to eq "<pre>:foo</pre>"
          expect(subject.format_object(:foo, :inline)).to eq %Q{<span class="literal">:foo</span>}
        end
      end
      context "long String" do
        it "returns HTML" do
          str = "0123456789" * 10
          expect(subject.format_object(str)).to eq %Q{<pre>&quot;0123456789012345678901234567890123456789012345678901234567890123456789012345678&nbsp;↵\n901234567890123456789&quot;</pre>}
          expect(subject.format_object(str, :inline)).to eq %Q{<span class=\"literal\">&quot;01234567890123456789012345678901234567890123456789012345678901234567890123456789 ...</span>}
        end
      end
    end

    context "#format_method" do
      let(:meth) { Formatting.instance_method(:format_method) }
      it "returns HTML" do
        expect(subject.format_method(meth, :i)).to match(%r{<a href='//method/RackConsole::Formatting/i/format_method' title='.*lib/rack_console/formatting.rb:\d+' class='method_name'><span class=\"method_name\">format_method</span></a>})
      end
    end
  end
end

