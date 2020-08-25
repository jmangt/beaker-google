# frozen_string_literal: true

require 'spec_helper'

describe Beaker::GoogleCompute, focus: true do
  let(:target) { Beaker::GoogleCompute }

  let(:host_a) do
    {
      image: 'image-a',
      platform: 'platform-a'
    }
  end

  let(:host_b) do
    {
      image: 'image-b',
      platform: 'platform-b'
    }
  end

  let(:hosts) do
    [host_a, host_b]
  end

  let(:options) do
    make_opts
  end

  let(:gc) do
    target.new(hosts, options)
  end

  describe '.new' do
    it 'returns a new instance of Beaker::Google' do
      expect(target.new(hosts, options)).to be_instance_of(Beaker::GoogleCompute)
    end
  end

  describe '#find_google_ssh_public_key' do
    context 'when ssh public key file is not present' do
      it 'should raise error when file is not present in default path' do
        error_msg = "Could not find GCE Public SSH Key at '#{ENV['HOME']}/.ssh/google_compute_engine.pub'"

        expect do
          gc.find_google_ssh_public_key
        end.to raise_error(RuntimeError, error_msg)
      end

      it 'should raise error when BEAKER_gce_ssh_public_key is set to incorrect path' do
        FakeFS do
          stub_ssh_public_key
          ssh_key_path = '/tmp/google_compute_engine.pub'
          ENV['BEAKER_gce_ssh_public_key'] = ssh_key_path
          error_msg = "Could not find GCE Public SSH Key at '#{ssh_key_path}'"
          expect do
            gc.find_google_ssh_public_key
          end.to raise_error(RuntimeError, error_msg)
        end
      end
    end

    # context 'when ssh public key file is present' do
    #   it 'should return default path to ssh public key' do
    #     expect(gc.find_google_ssh_public_key).to eql("#{ENV['HOME']}/.ssh/google_compute_engine.pub")
    #   end
    # end
  end
end
