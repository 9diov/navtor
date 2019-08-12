require 'navtor/value'

module Navtor
  class FileManager; end

  class UIState < Value.new(:lines, :cols, :offset, :start_line, :end_line, :current_line)
    def page_size
      end_line - start_line
    end

    def reset
      self.merge(current_line: 0, offset: 0)
    end
  end

  class UI
    attr_accessor :start_line, :end_line

    def initialize(file_manager)
      @file_manager = file_manager
      init_curses
      init_screen
      @state = init_state
      @input = nil
    end

    def reset
      @state = @state.reset
    end

    def init_curses
      Curses.noecho
      Curses.nonl
      Curses.stdscr.keypad(true)
      Curses.raw
      Curses.stdscr.nodelay = 1
    end

    def init_screen
      Curses.init_screen
      Curses.start_color
      Curses.use_default_colors
      Curses.init_pair(1, -1, -1) # Get defautl colors
      Curses.init_pair(2, Curses::COLOR_GREEN, -1)
      Curses.curs_set(0)
      Curses.stdscr.timeout = -1
      Curses.stdscr.scrollok(false) # Avoid scrolling
      Curses.stdscr.idlok(true)
    end

    def init_state
      UIState.with(
        lines: Curses.lines,
        cols: Curses.cols,
        offset: 0, # Offset within current directory's entries
        start_line: 0, # Start line of file list on screen, should be 0
        end_line: Curses.lines - 1, # End line of file list on screen
        current_line: 0
      )
    end

    def close_screen
      Curses.close_screen
    end

    def calculate_lines(entries)
      @state = @state.merge(end_line: [@state.lines - 2, entries.size-1].min)
    end

    def stdscr
      Curses.stdscr
    end

    def refresh!
      Curses.clear
      stdscr.refresh
    end

    # Print entries and return current position
    def print_entries(entries, current_pos)
      visible_entries = entries[@state.offset + @state.start_line, @state.end_line - @state.start_line + 1]
      new_pos = nil
      visible_entries.each.with_index do |line, index|
        if index == @state.current_line
          new_pos = index + @state.offset
          stdscr.attron(Curses.color_pair(1) | Curses::A_REVERSE) {
            stdscr.addstr("#{line}")
          }
        else
          stdscr.addstr("#{line}")
        end
        stdscr.setpos(stdscr.cury + 1, 0)
      end
      stdscr.addstr("(empty)") if visible_entries.empty?
      stdscr.refresh

      new_pos
    end

    def render_status_line(entries, current_pos, clear = true)
      curx, cury = stdscr.curx, stdscr.cury
      str = "#{Dir.pwd} (#{entries[current_pos]}) (#{current_pos + 1}/#{entries.size}) off=#{@state.offset} cur=#{@state.current_line} end=#{@state.end_line} w=#{@state.cols} h=#{@state.lines} input=#{@input}"
      if clear
        stdscr.setpos(@state.lines - 1, 0)
        stdscr.addstr(' ' * @state.cols)
      end
      stdscr.setpos(@state.lines - 1, 0)
      stdscr.attron(Curses.color_pair(2) | Curses::A_NORMAL) {
        stdscr.addstr(str)
      }
      stdscr.setpos(cury, curx)
      stdscr.refresh
    end

    def render(fm_state)
      entries, current_pos = fm_state
      refresh!
      new_pos = print_entries(entries, current_pos)
      current_pos = new_pos unless new_pos.nil?
      render_status_line(entries, current_pos)
    end

    def get_input
      @input = stdscr.getch
    end

    def exit_input
      get_input == 'q'
    end

    def handle_input(fm_state)
      action = handle(@input, fm_state.entries)
      @file_manager.send(action) if action
    end

    # @return actions to be executed by file manager
    def handle(input, entries)
      if input == 'j' || input == 258
        @state = @state.merge(current_line: (@state.current_line == @state.end_line) ? @state.current_line : @state.current_line + 1)
        @state = @state.merge(offset: @state.offset + 1) if @state.current_line == @state.end_line && @state.offset + @state.page_size < entries.size - 1
        :down1
      elsif input == 'k' || input == 259
        @state = @state.merge(current_line: (@state.current_line == @state.start_line) ? @state.current_line : @state.current_line - 1)
        @state = @state.merge(offset: @state.offset - 1) if @state.current_line == @state.start_line && @state.offset > 0
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

    def exit
      Curses.clear
      Curses.close_screen
    end
  end
end
