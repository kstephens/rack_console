require 'spec_helper'
require 'rack_console/source_file'

module RackConsole
  describe SourceFile do
    subject { SourceFile.new([file, line]).load! }
    let(:file) { $".grep(%r{rack_console/source_file}).first }
    let(:line) { 11 }
    context "#narrow_to_block!" do
      let(:lines) { subject.lines.map{|h| h[:str]} * "\n" }
      it "returns expected lines" do
        subject.narrow_to_block!
        expect(lines) .to_not match(/^\s+class$/)
        expect(lines) .to_not match(/^\s+def initialize/)
        expect(lines) .to match(/^\s+attr_reader/)
        expect(lines) .to match(/^\s+def load!/)
        expect(lines) .to match(/^\s+self(\s*)$/)
        expect(lines) .to match(/^\s+end(\s*)$/)
        expect(lines) .to match(/^\s+def highlight_block!$/)
        expect(lines) .to_not match(/^\s+def narrow_to_block!$/)
      end
    end
  end
end

