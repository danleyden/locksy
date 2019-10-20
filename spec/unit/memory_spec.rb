require_relative './spec_helper'
require_relative './shared_examples'
require 'locksy/memory'

def new_lock(**args)
  Locksy::Memory.new(**args).tap { |ins| ins._clock = clock }
end

describe Locksy::Memory do
  subject(:instance) { new_lock(**init_args) }
  let(:other_owner) { new_lock(owner: 'another', **init_args) }
  let(:other_named_lock) { new_lock(**init_args, lock_name: 'other-lock-name') }
  let(:init_args) { { lock_name: lock_name } }
  let(:clock) do
    double('clock').tap { |clk| allow(clk).to receive(:now).and_return(*times) }
  end
  let(:times) { [30] }
  let(:data_change_cv) { double(:data_change_cv, broadcast: nil, signal: nil) }
  let(:lock_name) { 'my-test-lock-name' }
  before do
    Locksy::Memory._data_change = data_change_cv
    allow(data_change_cv).to receive(:wait) { Thread.pass }
  end
  after do
    Locksy::Memory.release_all!
    Locksy::Memory._data_change = ConditionVariable.new
  end

  it_behaves_like 'a lock'
end
