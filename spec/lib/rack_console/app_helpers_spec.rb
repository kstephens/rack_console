require 'spec_helper'
require 'rack_console/app_helpers'

module RackConsole
  describe AppHelpers do
    subject { OpenStruct.new(config: config).extend(AppHelpers) }
    let(:config) { { } }
    context "#const_get_safe" do
      it "returns safely" do
        expect(subject.const_get_safe(RackConsole, "AppHelpers")).to eq AppHelpers
        expect(subject.const_get_safe(RackConsole, :ALSKJFSDKJF)).to eq "ERROR: #<NameError: uninitialized constant RackConsole::ALSKJFSDKJF>"
      end
    end
  end
end

