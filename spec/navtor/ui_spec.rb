require_relative './spec_helper'
require 'navtor/ui'
require 'navtor/file_manager'

describe Navtor::UI do
  let (:fm_state) {
    Navtor::FMState.with(
      entries: ['a.txt', '[b]'],
      current_pos: 0,
      current_dir: '/tmp'
    )
  }
  let (:ui) { described_class.new }

  describe 'State calculation' do
    it 'can calculate state' do
      state = ui.init_state(10, 10)
      new_state = ui.calculate_state(state, fm_state)

      expect(new_state.start_line).to eq(0)
      expect(new_state.end_line).to eq(1)
      expect(new_state.current_dir).to eq('/tmp')
    end
  end

  describe 'Input handling' do
    it 'can handle down1 input' do
      ui.state = ui.init_state(10, 10)
      action = ui.handle_input('j', fm_state)
      expect(action).to eq(:down1)
      expect(ui.state.current_line).to eq(1)

      action = ui.handle_input('j', fm_state)
      expect(action).to eq(:down1)
      expect(ui.state.current_line).to eq(2)
    end
  end
end

