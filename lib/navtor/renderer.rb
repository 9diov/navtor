# typed: true
require 'curses'

module Navtor
  class Renderer
    def init!
      init_curses!
      init_screen!
    end

    def init_curses!
      Curses.noecho
      Curses.nonl
      Curses.stdscr.keypad(true)
      Curses.raw
      Curses.stdscr.nodelay = 1
    end

    def init_screen!
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

    def get_lines_cols
      [Curses.lines, Curses.cols]
    end

    def close_screen!
      Curses.close_screen
    end

    def refresh!
      Curses.clear
      stdscr.refresh
    end

    def exit!
      Curses.clear
      Curses.close_screen
    end

    def render_entries!(visible_entries, current_line)
      refresh!
      visible_entries.each.with_index do |line, index|
        if index == current_line
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

    def render_status_line!(new_state, entries, current_pos, clear = true)
      curx, cury = stdscr.curx, stdscr.cury
      str = "#{new_state.current_dir} (#{entries[current_pos]}) (#{current_pos + 1}/#{entries.size}) off=#{new_state.offset} cur=#{new_state.current_line} end=#{new_state.end_line} w=#{new_state.cols} h=#{new_state.lines} input=#{@input}"
      if clear
        stdscr.setpos(new_state.lines - 1, 0)
        stdscr.addstr(' ' * new_state.cols)
      end
      stdscr.setpos(new_state.lines - 1, 0)
      stdscr.attron(Curses.color_pair(2) | Curses::A_NORMAL) {
        stdscr.addstr(str)
      }
      stdscr.setpos(cury, curx)
      stdscr.refresh
    end

    def get_input
      stdscr.getch
    end

    private
    def stdscr
      Curses.stdscr
    end
  end
end
