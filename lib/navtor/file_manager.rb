require 'navtor/ui'
require 'pry'

module Navtor
  class FMState < Value.new(:entries, :current_pos)
    def current_entry
      entries[current_pos]
    end
  end

  class FileManager
    attr_accessor :state

    def initialize
      @state = FMState.with(entries: [], current_pos: 0)
      @ui = Navtor::UI.new
      ls
    end

    def run
      @ui.render(@state)
      until (input = @ui.get_input) == @ui.exit_input
        action = @ui.handle_input(input, @state)
        self.send(action) if action
        @ui.render(@state)
      end
      @ui.exit
    end

    def ls
      @state = @state.merge(entries: list_entries, current_pos: 0)
    end

    def current_entry
      @state.current_entry
    end

    # Actions
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
        @ui.refresh!
      end
    end

    def up1
      @state = @state.merge(current_pos: @state.current_pos - 1) if @state.current_pos > 0
    end

    def down1
      @state = @state.merge(current_pos: @state.current_pos + 1) if @state.current_pos < @state.entries.size - 1
    end

    def to_top
      @state = @state.merge(current_pos: 0)
    end

    def to_bottom
      @state = @state.merge(current_pos: @state.entries.size > 0 ? @state.entries.size - 1 : 0)
    end
    private

    # @return Array of files and directories in current directory
    def list_entries
      (Dir.entries('.') - ['.', '..']).sort.map.with_index do |entry, index|
        if File.directory?(entry)
          "[#{entry}]"
        else
          entry
        end
      end
    end
  end
end
