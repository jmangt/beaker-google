# frozen_string_literal: true

require 'spec_helper'

describe Beaker::GoogleCompute do
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
    before(:each) do
      @home = ENV['HOME']
    end

    after(:each) do
      ENV['HOME'] = @home
      ENV['BEAKER_gce_ssh_public_key'] = nil
    end

    let(:ssh_key_path) do
      '/tmp/.ssh/google_compute_engine.pub'
    end

    context 'when ssh public key file is not present' do
      it 'should raise error when file is not present in default path' do
        error_msg = "Could not find GCE Public SSH Key at '#{ENV['HOME']}/.ssh/google_compute_engine.pub'"
        expect do
          gc.find_google_ssh_public_key
        end.to raise_error(RuntimeError, error_msg)
      end

      it 'should raise error when BEAKER_gce_ssh_public_key is set to incorrect path' do
        g = gc
        error_msg = "Could not find GCE Public SSH Key at '#{ssh_key_path}'"
        ENV['BEAKER_gce_ssh_public_key'] = ssh_key_path

        expect do
          ENV['HOME'] = '/tmp'
          g.find_google_ssh_public_key
        end.to raise_error(RuntimeError, error_msg)
      end

      it 'should raise error when gce_ssh_public_key is set to incorrect path' do
        g = target.new(hosts, options.merge({ gce_ssh_public_key: ssh_key_path }))
        error_msg = "Could not find GCE Public SSH Key at '#{ssh_key_path}'"
        expect do
          ENV['HOME'] = '/tmp'
          g.find_google_ssh_public_key
        end.to raise_error(RuntimeError, error_msg)
      end
    end

    context 'when ssh public key file is present' do
      it 'should return default path to ssh public key' do
        g = gc
        FakeFS do
          ENV['HOME'] = '/tmp'
          stub_ssh_public_key
          expect(g.find_google_ssh_public_key).to eql("#{ENV['HOME']}/.ssh/google_compute_engine.pub")
        end
      end

      it 'should return path set by BEAKER_gce_ssh_public_key' do
        g = gc
        FakeFS do
          ENV['HOME'] = '/tmp'
          ENV['BEAKER_gce_ssh_public_key'] = ssh_key_path
          stub_ssh_public_key
          expect(g.find_google_ssh_public_key).to eql(ssh_key_path)
        end
      end

      it 'should return path set by options gce_ssh_public_key' do
        g = target.new(hosts, options.merge({ gce_ssh_public_key: ssh_key_path }))

        FakeFS do
          ENV['HOME'] = '/tmp'
          stub_ssh_public_key
          expect(g.find_google_ssh_public_key).to eql(ssh_key_path)
        end
      end
    end
  end

  describe '#format_metadata' do
    before(:each) do
      @home = ENV['HOME']
    end

    after(:each) do
      ENV['HOME'] = @home
    end

    it 'retuns an array of metadata' do
      g = gc
      FakeFS do
        ENV['HOME'] = '/tmp'
        stub_ssh_public_key
        expect(g.format_metadata).to be_instance_of(Array)
      end
    end

    it 'sets metadata based on options' do
      g = target.new(hosts, options.merge({ department: 'my-dep', project: 'my-proj', jenkins_build_url: 'my-build-url' }))
      metadata = [
        { key: :department, value: 'my-dep' },
        { key: :project, value: 'my-proj' },
        { key: :jenkins_build_url, value: 'my-build-url' },
        { key: :sshKeys, value: 'google_compute:ABC123' }
      ]
      FakeFS do
        ENV['HOME'] = '/tmp'
        stub_ssh_public_key
        expect(g.format_metadata).to eql(metadata)
      end
    end
  end
end
