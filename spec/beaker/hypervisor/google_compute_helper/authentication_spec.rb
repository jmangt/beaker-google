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

  # #<Google::APIClient:0x00007fe0323cc890 @host="www.googleapis.com", @port=443, @discovery_path="/disco...pter::NetHttp]>, @url_prefix=#<URI::HTTP http:/>, @manual_proxy=false, @proxy=nil, @temp_proxy=nil>>
  describe '#set_client' do
    it 'returns an instance of Google::APIClient based on the version of beaker' do
      expect(gch.set_client(Beaker::Version::STRING)).to be_kind_of(Google::APIClient)
    end

    it 'sets the value of @client' do
      gch.set_client(Beaker::Version::STRING)
      expect(gch.instance_variable_get(:@client)).to be_kind_of(Google::APIClient)
    end
  end

  describe '#set_compute_api' do
    it 'sets the value of the Google Compute api to use' do
      VCR.use_cassette('google_compute_helper/set_compute_api') do
        gch.set_compute_api(Beaker::GoogleComputeHelper::API_VERSION, Time.now, 20)
        expect(gch.instance_variable_get(:@compute)).to be_kind_of(Google::APIClient::API)
      end
    end
  end

  describe '#authenticate' do
    it 'raises error when gce_keyfile is not found' do
      opts = options
      opts[:gce_keyfile] = '/path/does-not-exist.p12'
      FakeFS do
        expect { target.new(opts) }.to raise_error(RuntimeError, /Could not find gce_keyfile for Google Compute Engine/)
      end
    end

    it 'should set the value of @client.authorization' do
      client = gch.instance_variable_get(:@client)
      expect(client.authorization).to be_kind_of(Signet::OAuth2::Client)
    end
  end
end
