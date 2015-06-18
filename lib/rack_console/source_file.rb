module RackConsole
  class SourceFile
    attr_reader :file, :line
    def initialize source_location
      @file, @line = Array(source_location)
    end

    attr_accessor :lines
    attr_reader :block_beg, :block_end, :block_indent

    def load!
      @lines ||= File.read(@file).split("\n")

      line = 0
      @lines.map! do | l |
        line += 1
        c = [ :source_line ]
        case @line
        when nil
          c << :normal_line
        when line
          c << :selected_line
        else
          c << :unselected_line
        end
        { index: line - 1, line: line, str: l, class: c }
      end
      highlight_block! if @line
      self
    end

    def highlight_block!
      block_indent = last_line = nil
      @lines.each do | l |
        indent = (l[:str] =~ /^(\s*)\S/ && $1) || ''
        add_classes = block_finished = nil
        case
        when l[:line] == @line
          @block_beg = l
          add_classes = [ :block, :block_begin ]
          @block_indent = indent
          block_indent = indent.size
        when block_indent && (indent.size  > block_indent || l[:str] =~ /^(\s*)$/)
          add_classes = [ :block, :block_body ]
        when block_indent && (indent.size  < block_indent)
          add_classes = nil
          block_finished = true
        when block_indent &&  indent.size == block_indent
          if l[:str] =~ /^(\s*)(ensure|rescue)\b/
            add_classes = [ :block, :block_body ]
          else
            @block_end = l
            add_classes = [ :block, :block_end ]
            block_indent = nil
            block_finished = true
          end
          add_classes = [ :block, :block_body ]
        end
        if add_classes
          l[:class].concat(add_classes).delete(:unselected_line)
        end
        break if block_finished
      end
      self
    end

    def narrow_to_block! context_lines = 2
      if @block_beg
        lineno = @block_beg[:line] - context_lines
        @lines = @lines.select{|l| l[:line] >= lineno }
      end
      if @block_end
        lineno = @block_end[:line] + context_lines
        @lines = @lines.select{|l| l[:line] <= lineno }
      end
      self
    end

  end
end
