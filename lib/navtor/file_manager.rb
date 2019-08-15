require 'navtor/ui'
require 'pry'

module Navtor
  class FMState < Value.new(:entries, :current_pos, :current_dir)
    def _validate
      raise "Invalid position #{current_pos}, entries size = #{entries.size}" unless (0..entries.size).cover?(current_pos)
    end

    def current_entry
      entries[current_pos]
    end

    def up1
      return self if current_pos <= 0
      self.merge(current_pos: current_pos - 1)
    end

    def down1
      return self if current_pos == entries.size
      self.merge(current_pos: state.current_pos + 1)
    end

    def to_top
      self.merge(current_pos: 0)
    end

    def to_bottom
      self.merge(current_pos: [entries.size - 1, 0].max)
    end
  end

  class FileManager
    attr_accessor :state

    def initialize
      @ui = Navtor::UI.new
    end

    def initial_state
      FMState.with(entries: [], current_pos: 0, current_dir: Dir.pwd)
    end

    def run(state)
      @ui.init_renderer!

      state = ls(state)
      @ui.render!(state)
      until (input = @ui.get_input) == @ui.exit_input
        action = @ui.handle_input(input, state)
        if action
          state = self.send(action, state)
          @ui.render!(state)
        end
      end
      @ui.exit
    end

    private

    # Action methods
    def to_parent_dir(state)
      Dir.chdir('..')
      state = ls(state)
    end

    def open_current(state)
      return if state.current_entry.nil?
      is_file = state.current_entry.match('\[(.+)\]').nil?
      if !is_file
        Dir.chdir(state.current_entry.match('\[(.+)\]')[1])
        state = ls(state)
      else
        @ui.submerge do
          system("vim #{Dir.pwd}/#{state.current_entry}")
        end
      end
      state
    end

    def up1(state)
      state.up1
    end

    def down1(state)
      state.down1
    end

    def to_top(state)
      state.to_top
    end

    def to_bottom(state)
      state.to_bottom
    end

    def ls(state)
      state.merge(entries: list_entries, current_pos: 0, current_dir: Dir.pwd)
    end

    ## Helper methods

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
