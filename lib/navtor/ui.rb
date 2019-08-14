require 'navtor/value'
require 'navtor/renderer'

module Navtor
  class UIState < Value.new(:lines, :cols, :offset, :start_line, :end_line, :current_line, :current_dir)
    def _validate
      raise "Invalid start_line: #{start_line}" if start_line < 0
      raise "end_line (#{end_line}) must be larger than start_line (#{start_line})" if start_line > end_line
      raise "Invalid current_line #{current_line}, start_line = #{start_line}, end_line = #{end_line}; current_state #{self}" if current_line < start_line || current_line > end_line
    end

    def page_size
      end_line - start_line
    end

    def reset
      self.merge(current_line: 0, offset: 0)
    end

    def next_state(fm_state)
      new_state = self
      if current_dir != fm_state.current_dir
        new_state = self.merge(current_dir: fm_state.current_dir).reset
      end
      new_state.merge(end_line: [[new_state.lines - 2, fm_state.entries.size-1].min, 0].max)

      new_state
    end

    def down1(fm_state)
      new_state = self.merge(current_line: [current_line + 1, end_line].min)
      new_state = new_state.merge(offset: offset + 1) if current_line == end_line && offset + page_size < fm_stat.entries.size - 1

      new_state
    end

    def up1(fm_state)
      new_state = self.merge(current_line: (current_line == start_line) ? current_line : current_line - 1)
      new_state = new_state.merge(offset: offset - 1) if current_line == start_line && offset > 0

      new_state
    end
  end

  class UI
    attr_accessor :state

    def initialize
      @renderer = Navtor::Renderer.new
    end

    def init_renderer!
      @renderer.init!
      @state = init_state(*@renderer.get_lines_cols)
    end

    def init_state(lines, cols)
      UIState.with(
        lines: lines,
        cols: cols,
        offset: 0, # Offset within current directory's entries
        start_line: 0, # Start line of file list on screen, should be 0
        end_line: lines - 1, # End line of file list on screen
        current_line: 0,
        current_dir: ''
      )
    end

    def visible_entries(new_state, entries)
      entries[new_state.offset + new_state.start_line, new_state.end_line - new_state.start_line + 1]
    end

    def render!(fm_state)
      entries, current_pos, _ = fm_state
      @state = @state.next_state(fm_state)
      @renderer.render_entries!(visible_entries(@state, entries), @state.current_line)
      @renderer.render_status_line!(@state, entries, current_pos)
    end

    def get_input
      @renderer.get_input
    end

    def exit_input
      'q'
    end

    # @return actions to be executed by file manager
    def handle_input(input, fm_state)
      entries = fm_state.entries
      if input == 'j' || input == 258
        @state = @state.send(:down1, fm_state)
        :down1
      elsif input == 'k' || input == 259
        #@state = @state.merge(current_line: (@state.current_line == @state.start_line) ? @state.current_line : @state.current_line - 1)
        #@state = @state.merge(offset: @state.offset - 1) if @state.current_line == @state.start_line && @state.offset > 0
        @state = @state.send(:up1, fm_state)
        :up1
      elsif input == 'g'
        @state = @state.merge(
          offset: 0,
          current_line: 0
        )
        :to_top
      elsif input == 'G'
        @state = @state.merge(offset: entries.size - 1 - @state.page_size)
        @state = @state.merge(current_line: @state.end_line)
        :to_bottom
      elsif input == 'h' || input == 260
        @state = @state.merge(offset: 0)
        :to_parent_dir
      elsif input == 'l' || input == 261
        :open_current
      end
    end

    def submerge(&blk)
      @renderer.close_screen!
      #Curses.def_prog_mode
      blk.call
      #Curses.reset_prog_mode
      @renderer.init_screen!
      @renderer.refresh!
    end
  end
end
