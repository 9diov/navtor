# typed: false
require_relative './spec_helper'
require 'navtor/ui'
require 'navtor/file_manager'

describe Navtor::UIState do
  let (:state) {
    described_class.with(
      lines: 80,
      cols: 40,
      offset: 0,
      start_line: 0,
      end_line: 20,
      current_line: 5,
      current_dir: '/'
    )
  }
  let (:fm_state) {
    Navtor::FMState.with(
      entries: ['alice.txt', '[bill]', 'celine.mp3', 'david.xlsx'],
      current_pos: 0,
      current_dir: '/tmp'
    )
  }

  it 'can move around' do
    expect(state.down1(fm_state).current_line).to eq(6)
    expect(state.down1(fm_state).down1(fm_state).current_line).to eq(7)
  end

  it 'can get next state' do
    expect(state.next_state(fm_state).current_line).to eq(0)
    expect(state.next_state(fm_state).down1(fm_state).current_line).to eq(1)
    expect(state.next_state(fm_state).down1(fm_state).down1(fm_state).current_line).to eq(2)
    expect(state.next_state(fm_state).down1(fm_state).down1(fm_state).to_top.current_line).to eq(0)
    expect(state.next_state(fm_state).down1(fm_state).down1(fm_state).to_bottom(fm_state).current_line).to eq(3)
  end
end

describe Navtor::UI do
  let (:fm_state) {
    Navtor::FMState.with(
      entries: ['a.txt', '[b]'],
      current_pos: 0,
      current_dir: '/tmp'
    )
  }
  let (:ui) { described_class.new }

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

