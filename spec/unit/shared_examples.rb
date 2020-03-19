require_relative './spec_helper'

shared_examples 'a lock' do
  shared_examples 'another owner cannot obtain the same lock' do
    it { expect { other_owner.obtain_lock }.to raise_error(Locksy::LockNotOwnedError) }
  end

  describe 'obtaining a lock' do
    shared_context 'after obtaining the lock' do
      before { instance.obtain_lock }
      it_behaves_like 'another owner cannot obtain the same lock'
    end

    context 'when there is no lock with that name' do
      it { expect { instance.obtain_lock }.not_to raise_error }
      include_context 'after obtaining the lock'
    end

    context 'when there is a lock with a different name' do
      before { other_named_lock.obtain_lock }

      it { expect { instance.obtain_lock }.not_to raise_error }
      include_context 'after obtaining the lock'
    end

    context 'when there is lock with that name' do
      context 'and it is owned by the same owner' do
        before { instance.obtain_lock }
        it { expect { instance.obtain_lock }.not_to raise_error }
        include_context 'after obtaining the lock'
      end

      context 'and it is owned by a different owner' do
        before { other_owner.obtain_lock }
        it { expect { instance.obtain_lock }.to raise_error(Locksy::LockNotOwnedError) }

        context 'and the owned lock has expired' do
          let(:times) { [20, 1000] }

          it { expect { instance.obtain_lock }.not_to raise_error }
          include_context 'after obtaining the lock'
        end

        context 'and the caller is willing to wait for the lock' do
          let(:times) { Array.new(18, 20).append(1000) }
          it { expect { instance.obtain_lock(wait_for: 0.00000001) }.not_to raise_error }
        end
      end
    end

    context 'when there was a lock with a different owner that has been released' do
      before do
        other_owner.obtain_lock
        other_owner.release_lock
      end

      it { expect { instance.obtain_lock }.not_to raise_error }
    end
  end

  describe 'releasing a lock' do
    context 'when there is no lock' do
      it { expect { instance.release_lock }.not_to raise_error }
    end

    context 'when there is a lock' do
      context 'and it is owned by the same owner' do
        it { expect { instance.release_lock }.not_to raise_error }
      end

      context 'and it is owned by a different owner' do
        before { other_owner.obtain_lock }
        it { expect { instance.release_lock }.to raise_error(Locksy::LockNotOwnedError) }

        context 'and the owned lock has expired' do
          let(:times) { [20, 1000] }
          it { expect { instance.release_lock }.not_to raise_error }
        end
      end
    end
  end

  describe 'refreshing a lock' do
    shared_context 'after refreshing the lock' do
      before { instance.refresh_lock }
      it_behaves_like 'another owner cannot obtain the same lock'
    end

    context 'when there is no lock' do
      it { expect { instance.refresh_lock }.not_to raise_error }
      include_context 'after refreshing the lock'
    end

    context 'when there is a lock' do
      context 'and it is owned by the same owner' do
        before { instance.obtain_lock }
        it { expect { instance.refresh_lock }.not_to raise_error }
        include_context 'after refreshing the lock'
      end

      context 'and it is owned by a different owner' do
        before { other_owner.obtain_lock }
        it { expect { instance.refresh_lock }.to raise_error(Locksy::LockNotOwnedError) }

        context 'and the owned lock has expired' do
          let(:times) { [20, 1000] }
          it { expect { instance.refresh_lock }.not_to raise_error }
        end
      end
    end
  end
end
