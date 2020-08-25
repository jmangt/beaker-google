# frozen_string_literal: true

require 'spec_helper'

describe Beaker::Google do
  let(:target) { Beaker::Google }

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

  context '.new' do
    it 'returns a new instance of Beaker::Google' do
      expect(target.new(hosts, options)).to be_instance_of(Beaker::Google)
    end
  end
end
