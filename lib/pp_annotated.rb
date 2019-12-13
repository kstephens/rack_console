require 'pp'

# A version of PP that calls an annotater
# around each object.
# Allows decorating objects.
class PPAnnotated < PP
  def self.pp annotater, *args
    annotater.pp_class(self, *args) do
      pp_internal(annotater, *args)
    end
  end

  # Yup, because PP.pp hardcodes PP.new()
  # instead of using self.new(), we
  # cannot call super.
  def self.pp_internal(annotater, obj, out=$>, width=79)
    q = new(annotater, out, width)
    # binding.pry
    q.guard_inspect_key do
      # binding.pry
      q.pp obj
    end
    q.flush
    #$pp = q
    out << "\n"
  end

  def initialize annotater, *args
    @annotater = annotater
    super(*args)
  end

  module PPMethods
    include ::PP::PPMethods
    # define_method(:pp, PP::PPMethods.instance_method(:pp))
    alias :pp_super :pp
    def pp *args
      # binding.pry
      @annotater.pp(self, *args) do
        pp_super(*args)
      end
    end
=begin
  alias :pretty_print_super :pretty_print
  def pretty_print *args
    binding.pry
    @annotater.pretty_print(self, *args) do
      pretty_print_super(*args)
    end
  end

  alias :text_super :text
  def text(obj, width=obj.length)
    binding.pry
    @annotater.text(self, obj, width) do
      text_super(obj, width)
    end
  end
=end
  end
  prepend PPMethods

  class AnnotatedPrettyPrint < ::PrettyPrint
    def initialize annotater, *args
      @annotater = annotater
      super(*args)
      # binding.pry
    end

=begin
  alias :pretty_print_super :pretty_print
  def pretty_print *args
    binding.pry
    @annotater.pretty_print(self, *args) do
      pretty_print_super(*args)
    end
  end

  alias :text_super :text
  def text(obj, width=obj.length)
    binding.pry
    @annotater.text(self, obj, width) do
      text_super(obj, width)
    end
  end
=end
  end

  # Base class
  class Annotater
    def pp_class p, obj, *args
      yield
    end

    def pp p, obj, *args
      yield
    end

    def pretty_print p, obj
      yield
    end

    def text p, *args
      yield
    end
  end
end


