# frozen_string_literal: true

require 'spec_helper'
require 'rack_console/source_file'

module RackConsole
  describe SourceFile do
    subject { SourceFile.new([file, line]).load! }
    let(:file) { __FILE__ }
    let(:line) { SourceFile.new([file, 1]).load!.find_line(/^\s+def foo!/)[:line] }

    context "#narrow_to_block!" do
      let(:lines) { subject.lines.map{|h| h[:str]} * "\n" }

      it "returns expected lines" do
        subject.narrow_to_block!
        expect(lines) .to_not match(/^\s+class$/)
        expect(lines) .to_not match(/^\s+def initialize/)
        expect(lines) .to match(/^\s+attr_reader :d/)
        expect(lines) .to match(/^\s+def foo!/)
        expect(lines) .to match(/^\s+self(\s*)$/)
        expect(lines) .to match(/^\s+end(\s*)$/)
        expect(lines) .to match(/^\s+def bar!$/)
        expect(lines) .to_not match(/^\s+def not_this!$/)
      end
    end
  end

  # IF YOU MODIFY THIS CLASS, YOU MAY NEED TO UPDATE THE SPEC
  class SourceFile::Test
    attr_accessor :a, :b, :c
    def initialize a, b, c
      @a, @b, @c = a, b, c
    end

    attr_reader :d

    def foo!
      if a
        b
      else
        c
      end
      self
    end

    def bar!
      do_something_else
    end

    def not_this!
    end
  end

end

