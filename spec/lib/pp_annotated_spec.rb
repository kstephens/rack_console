require 'spec_helper'
require 'pp_annotated'
require 'stringio'

describe PPAnnotated do
  subject { PPAnnotated }
  let(:annotater) { PPAnnotated::TestAnnotater.new }
  let(:object) do
    {
      a: 2,
      b: "a string",
      c: Kernel,
    }
  end
  let(:width)  { 100 }
  let(:output) { StringIO.new }
  context "#pp" do
    it "wraps with <span> tags" do
      subject.pp(annotater, object, output, width)
      expected = <<END
<span class='Hash'>{<span class='Symbol'>:a</span>=><span class='Integer'>2</span>,
 <span class='Symbol'>:b</span>=><span class='String'>"a string"</span>,
 <span class='Symbol'>:c</span>=><span class='Kernel'>Kernel</span>}</span>
END
      expect(output.string)
        .to eq expected
    end
  end
end

class PPAnnotated::TestAnnotater < PPAnnotated::Annotater
  def pp p, obj, *args
    wrap_obj(p, obj) do
      yield
    end
  end

  def pretty_print p, obj
    wrap_obj(p, obj) do
      yield
    end
  end

  def text p, *args
    yield
  end

  def wrap_obj p, obj
    # binding.pry
    mod = Module === obj ? obj : obj.class
    cls = module_to_html_class(mod)
    p.text("<span class='#{cls}'>")
    yield
    p.text("</span>")
  end

  def module_to_html_class mod
    mod.name.gsub('_', '__').gsub(':', '_5f')
  end
end

