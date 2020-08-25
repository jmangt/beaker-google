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

  # { "autoCreateSubnetworks" => true,
  #   "creationTimestamp" => "2019-05-23T12:36:17.178-07:00",
  #   "description" => "Default network for the project",
  #   "id" => "9057685004058577118",
  #   "kind" => "compute#network",
  #   "name" => "default",
  #   "routingConfig" => {"routingMode"=>"REGIONAL"},
  #   "selfLink" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default",
  #   "subnetworks" => ["https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/us-west3/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/europe-west3/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/europe-west2/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/europe-west4/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/asia-south1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/europe-west1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/us-west4/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/us-west2/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/asia-northeast1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/europe-north1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/asia-southeast2/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/australia-southeast1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/europe-west6/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/asia-east2/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/us-central1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/southamerica-east1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/us-east1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/us-east4/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/asia-northeast3/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/asia-northeast2/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/us-west1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/northamerica-northeast1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/asia-east1/subnetworks/default", "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/asia-southeast1/subnetworks/default"],
  # }
  describe '#get_network' do
    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'returns a hash with a GCE network object type request' do
      g = gch
      VCR.use_cassette('google_compute_helper/network_get_req', match_requests_on: %i[method uri]) do
        expect(g.get_network(start, attempts)).to be_kind_of(Hash)
      end
    end
  end

  # {:api_method=>#<Google::APIClient::Method:0x3fde9c1d4010 ID:compute.networks.get>, :parameters=>{"network"=>"default", "project"=>"beaker-compute", "zone"=>"us-central1-a"}}
  describe '#network_get_req' do
    let(:name) { 'default' }

    it 'Creates a Google Compute get network request' do
      request = gch.network_get_req(name)
      expect(request).to be_kind_of(Hash)
    end
  end

  # {:api_method=>#<Google::APIClient::Method:0x3fece20fb4f0 ID:compute.zoneOperations.get>, :parameters={ "name"=>"operation-1591366017070-...", "project"=>"beaker-compute", "zone"=>"us-central1-a"}}
  describe '#operation_get_req' do
    let(:zone_operation_name) { 'operation-1591366017070-...' }

    it 'Creates a Google Compute zone operation request' do
      request = gch.operation_get_req(zone_operation_name)
      expect(request).to be_kind_of(Hash)
    end
  end
end
