require 'spec_helper'
require 'rack_console/expr_helpers'

module RackConsole
  describe ExprHelpers do
    subject { OpenStruct.new.extend(ExprHelpers) }
    context "#expr_for_object" do
      [ nil,
        true, false,
        1234, 1234.56,
        "string", :symbol,
        Date.parse('2016-02-24'),
        Time.parse('2016-02-24 17:01:28'),
        ExprHelpers,
      ].each do | val |
        context "for #{val} #{val.class}" do
          it "returns valid expression where eval(expr) == #{val.inspect}" do
            expr = subject.expr_for_object(val)
            expect(eval(expr)) .to eq val
          end
        end
      end
    end
  end
end

