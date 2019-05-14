require 'navtor/ui'
#require 'pry'

module Navtor
  class FileManager
    attr_accessor :entries, :current_pos

    def initialize
      @entries = []
      @current_pos = 0
      @ui = Navtor::UI.new(self)
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
end
