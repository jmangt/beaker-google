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

  let(:gcp) do
  end

  # let(:options) do
  #   {
  #     logger: logger,
  #     timeout: 100,
  #     gce_project: 'my-project',
  #     gce_keyfile: 'my-keyfile'
  #   }
  # end

  context '.new' do
    it 'returns a new instance of Beaker::Google' do
      expect(target.new(hosts, options)).to be_instance_of(Beaker::GoogleCompute)
    end
  end
end
