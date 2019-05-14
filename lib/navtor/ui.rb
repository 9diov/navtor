require 'navtor/value'

module Navtor
  class FileManager; end

  class UI < Value.new(file_manager: FileManager)
    attr_accessor :start_line, :end_line

    def _initialize(file_manager)
      Curses.noecho
      Curses.nonl
      Curses.stdscr.keypad(true)
      Curses.raw
      Curses.stdscr.nodelay = 1
      self.init_screen
      @lines = Curses.lines
      @cols = Curses.cols
      @offset = 0 # Offset within current directory's entries

      @start_line = 0 # Start line of file list on screen, should be 0
      @end_line = @lines - 1 # End line of file list on screen
      @current_line = 0

      @input = nil
      stdscr.timeout = -1
      stdscr.scrollok(false) # Avoid scrolling
      stdscr.idlok(true)
    end

    def init_screen
      Curses.init_screen
      Curses.start_color
      Curses.use_default_colors
      Curses.init_pair(1, -1, -1) # Get defautl colors
      Curses.init_pair(2, Curses::COLOR_GREEN, -1)
      Curses.curs_set(0)
    end

    def close_screen
      Curses.close_screen
    end

    def calculate_lines
      @end_line = [@lines - 2, @file_manager.entries.size-1].min
    end

    def page_size
      @end_line - @start_line
    end

    def stdscr
      Curses.stdscr
    end

    def reset
      @current_line = 0
      @offset = 0
    end

    def refresh
      Curses.clear
      stdscr.refresh
    end

    def print_entries
      visible_entries = @file_manager.entries[@offset + @start_line, @end_line - @start_line + 1]
      visible_entries.each.with_index do |line, index|
        if index == @current_line
          @file_manager.current_pos = index + @offset
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
    end

    def status_line(str="", clear = true)
      curx, cury = stdscr.curx, stdscr.cury
      str = "#{Dir.pwd} (#{@file_manager.current_pos + 1}/#{@file_manager.entries.size}) off=#{@offset} cur=#{@current_line} end=#{@end_line} w=#{@cols} h=#{@lines} input=#{@input}" + str
      if clear
        stdscr.setpos(@lines - 1, 0)
        stdscr.addstr(' ' * @cols)
      end
      stdscr.setpos(@lines - 1, 0)
      stdscr.attron(Curses.color_pair(2) | Curses::A_NORMAL) {
        stdscr.addstr(str)
      }
      stdscr.setpos(cury, curx)
      stdscr.refresh
    end

    def run
      refresh
      print_entries
      status_line
      until (@input = stdscr.getch) == 'q'
        refresh
        handle(@input)
        print_entries
        status_line
      end
    ensure
      self.exit
    end

    def handle(input)
      if input == 'j' || input == 258
        @current_line = (@current_line == @end_line) ? @current_line : @current_line + 1
        @offset += 1 if @current_line == @end_line && @offset + page_size < @file_manager.entries.size - 1
      elsif input == 'k' || input == 259
        @current_line = (@current_line == @start_line) ? @current_line : @current_line - 1
        @offset -=1 if @current_line == @start_line && @offset > 0
      elsif input == 'g'
        @offset = 0
        @current_line = 0
      elsif input == 'G'
        @offset = @file_manager.entries.size - 1 - page_size
        @current_line = @end_line
      elsif input == 'h' || input == 260
        @offset = 0
        @file_manager.to_parent_dir
      elsif input == 'l' || input == 261
        @file_manager.open_current
      end
    end

    def exit
      Curses.clear
      Curses.close_screen
    end
  end
end
