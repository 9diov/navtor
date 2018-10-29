# This is a clone of fff written in Bash
# Things learned:
# * Need to remember to init_color
# * `Curses.init_pair(1, -1, -1)` can be used to get default colors
# * `stdscr.scrollok(false)` need to be used to avoid new line created at the bottom
require 'curses'

class FileManager
  attr_accessor :entries, :current_pos

  def initialize
    @entries = []
    @current_pos = 0
    @ui = UI.new(self)
    ls
  end

  def run
    @ui.run
  end

  def ls
    @entries = (Dir.entries('.') - ['.', '..']).sort
    @entries.each.with_index do |entry, index|
      if File.directory?(entry)
        @entries[index] = "[#{entry}]"
      end
    end
    @ui.calculate_lines
  end

  def current_entry
    @entries[@current_pos]
  end

  def to_parent_dir
    Dir.chdir('..')
    ls
    @ui.reset
  end

  def open_current
    return if current_entry.nil?
    is_file = current_entry.match('\[(.+)\]').nil?
    if !is_file
      Dir.chdir(current_entry.match('\[(.+)\]')[1])
      ls
      @ui.reset
    else
      @ui.close_screen
      #Curses.def_prog_mode
      system("vim #{Dir.pwd}/#{current_entry}")
      #Curses.reset_prog_mode
      @ui.init_screen
      @ui.refresh
    end
  end
end

class UI
  attr_accessor :start_line, :end_line
  def initialize(fm)
    @fm = fm
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
    @end_line = [@lines - 2, @fm.entries.size-1].min
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
    visible_entries = @fm.entries[@offset + @start_line, @end_line - @start_line + 1]
    visible_entries.each.with_index do |line, index|
      if index == @current_line
        @fm.current_pos = index + @offset
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
    str = "#{Dir.pwd} (#{@fm.current_pos + 1}/#{@fm.entries.size}) off=#{@offset} cur=#{@current_line} end=#{@end_line} w=#{@cols} h=#{@lines} input=#{@input}" + str
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
      @offset += 1 if @current_line == @end_line && @offset + page_size < @fm.entries.size - 1
    elsif input == 'k' || input == 259
      @current_line = (@current_line == @start_line) ? @current_line : @current_line - 1
      @offset -=1 if @current_line == @start_line && @offset > 0
    elsif input == 'g'
      @offset = 0
      @current_line = 0
    elsif input == 'G'
      @offset = @fm.entries.size - 1 - page_size
      @current_line = @end_line
    elsif input == 'h' || input == 260
      @offset = 0
      @fm.to_parent_dir
    elsif input == 'l' || input == 261
      @fm.open_current
    end
  end

  def exit
    Curses.clear
    Curses.close_screen
  end
end

def main
  fm = FileManager.new
  fm.run
end

main