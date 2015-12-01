module RackConsole
  class MockMethod
    attr_accessor :meth, :name, :kind, :owner
    def initialize *args
      @meth, @name, @kind, @owner = args
      @owner ||= @meth.owner
    end
    def instance_method?
      @kind == :i
    end
    def source_location
      @meth.source_location
    end
  end
end

