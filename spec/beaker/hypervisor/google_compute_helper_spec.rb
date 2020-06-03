# frozen_string_literal: true

require 'spec_helper'

describe Beaker::GoogleComputeHelper, focus: true do
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

  describe '#default_zone' do
    it 'returns default zone for requests' do
      expect(gch.default_zone).to eql 'https://www.googleapis.com/compute/v1/projects/beaker-compute/global/zones/us-central1-a'
    end
  end

  describe '#default_network' do
    it 'return default network for requests' do
      expect(gch.default_network).to eql 'https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default'
    end
  end

  describe '#get_platform_project' do
    it 'should raise error when no name is provided' do
      expect { gch.get_platform_project }.to raise_error(ArgumentError)
    end

    it 'should raise error when image name is not supported' do
      expect { gch.get_platform_project('my-custom-image') }.to raise_error(RuntimeError)
    end

    images = [
      { name: 'debian-foo', project: 'debian-cloud' },
      { name: 'centos-foo', project: 'centos-cloud' },
      { name: 'rhel-foo',   project: 'rhel-cloud' },
      { name: 'sles-foo',   project: 'sles-cloud' }
    ]

    images.each do |image|
      it "returns name of the compute project that contains the base image #{image[:name]}" do
        expect(gch.get_platform_project(image[:name])).to eql image[:project]
      end
    end
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

  # {:api_method=>#<Google::APIClient::Method:0x3fddb58b9854 ID:compute.images.list>, :parameters=>{"project"=>"beaker-compute"}}
  describe '#image_list_req' do
    it 'Creates a request for listing all images in a project' do
      request = gch.image_list_req(options[:gce_project])
      expect(request).to be_kind_of(Hash)
    end
  end

  # <Hash:70210724476060> => {"archiveSizeBytes"=>"16469314560", "creationTimestamp"=>"2019-05-15T19:01:21.060-07:00", "descriptio.../v1/projects/centos-cloud/global/images/centos-7-v20190515", "sourceType"=>"RAW", "status"=>"READY"}
  describe '#get_latest_image' do
    let(:platform) { 'centos-7-x86_64' }
    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'raises error if no matches are found' do
      stub_image_list_req('all-deprecated')
      expect { gch.get_latest_image(platform, start, attempts) }.to raise_error(RuntimeError, 'Unable to find a single matching image for centos-7-x86_64, found []')
    end

    it 'it returns a single image' do
      stub_image_list_req('centos-7')
      expect(gch.get_latest_image(platform, start, attempts)).to be_instance_of(Hash)
    end
  end

  # <Hash:70360533969540> => {:api_method=>#<Google::APIClient::Method:0x3ffe154a623c ID:compute.machineTypes.get>, :parameters=>{"machineType"=>"n1-highmem-2", "project"=>"beaker-compute", "zone"=>"us-central1-a"}}
  describe '#machineType_get_req' do
    it 'returns a hash with a GCE get machine type request' do
      g = gch
      VCR.use_cassette('google_compute_helper/machineType_get_req', match_requests_on: %i[method uri body]) do
        expect(g.machineType_get_req).to be_kind_of(Hash)
      end
    end
  end

  # <Hash:70360533969540> => {:api_method=>#<Google::APIClient::Method:0x3ffe154a623c ID:compute.machineTypes.get>, :parameters=>{"machineType"=>"n1-highmem-2", "project"=>"beaker-compute", "zone"=>"us-central1-a"}}
  describe '#get_machineType' do
    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'returns a hash with a GCE get machine type request' do
      g = gch
      VCR.use_cassette('google_compute_helper/machineType_get_req', match_requests_on: %i[method uri body]) do
        expect(g.get_machineType(start, attempts)).to be_kind_of(Hash)
      end
    end
  end
end
