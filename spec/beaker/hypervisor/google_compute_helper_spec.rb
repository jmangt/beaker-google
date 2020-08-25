# frozen_string_literal: true

require 'spec_helper'
require 'shared_examples'

describe Beaker::GoogleComputeHelper do
  let(:target) { Beaker::GoogleComputeHelper }

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
    make_opts.merge(
      timeout: 100,
      gce_keyfile: "#{ENV['HOME']}/.beaker/gce/beaker-compute.p12",
      gce_email: 'beaker-compute@beaker-compute.iam.gserviceaccount.com',
      gce_project: 'beaker-compute',
      gce_password: 'notasecret'
    )
  end

  let(:gch) do
    VCR.use_cassette('google_compute_helper/new_instance') do
      target.new(options)
    end
  end

  # clear any user local environment setttings
  before(:each) do
    ENV['BEAKER_gce_project'] = nil
    ENV['BEAKER_gce_keyfile'] = nil
  end

  describe '.new' do
    it 'returns a new instance of Beaker::GoogleComputeHelper' do
      expect(gch).to be_instance_of(target)
    end
  end
end
