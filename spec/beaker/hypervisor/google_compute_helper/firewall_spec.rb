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

  # {
  #   "id" => "3461028139834688623",
  #   "insertTime" => "2020-06-03T12:31:12.257-07:00",
  #   "kind" => "compute#operation",
  #   "name" => "operation-1591212671680-5a733120ebf2f-c83ae8cc-bbbad0c9",
  #   "operationType" => "insert",
  #   "progress" => 0,
  #   "selfLink" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/operations/operation-1591212671680-5a733120ebf2f-c83ae8cc-bbbad0c9",
  #   "startTime" => "2020-06-03T12:31:12.314-07:00",
  #   "status" => "RUNNING",
  #   "targetId" => "4313847222769435759",
  #   "targetLink" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/firewalls/beaker-tmp-firewall-rule",
  #   "user" => "beaker-compute@beaker-compute.iam.gserviceaccount.com",
  # }
  describe '#create_firewall' do
    let(:name) { 'beaker-create-firewall' }
    let(:network) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default' }
    end
    let(:start) { Time.now }
    let(:attempts) { 3 }

    before(:each) do
      VCR.use_cassette('google_compute_helper/create_firewall_before', match_requests_on: %i[method uri]) do
        gch.delete_firewall(name, start, attempts)
      end
    rescue StandardError
      puts "[WARN] #{name} firewall object not found"
    end

    after(:each) do
      VCR.use_cassette('google_compute_helper/create_firewall_after', match_requests_on: %i[method uri]) do
        gch.delete_firewall(name, start, attempts)
      end
    rescue StandardError
      puts "[WARN] #{name} firewall object not found"
    end

    it 'returns a hash with a GCE disk insertion confirmation' do
      VCR.use_cassette('google_compute_helper/create_firewall', match_requests_on: %i[method uri]) do
        expect(gch.create_firewall(name, network, start, attempts)).to be_kind_of(Hash)
      end
    end
  end

  # {:api_method=>#<Google::APIClient::Method:0x3fe0923c0f48 ID:compute.firewalls.list>, :parameters=>{"project"=>"beaker-compute", "zone"=>"us-central1-a"}}
  describe '#firewall_list_req' do
    it 'Creates a request for listing all firewall in a project' do
      VCR.use_cassette('google_compute_helper/firewall_list_req', match_requests_on: %i[method uri]) do
        request = gch.firewall_list_req
        expect(request).to be_kind_of(Hash)
      end
    end
  end

  # [{"allowed"=>
  #      [{"IPProtocol"=>"tcp", "ports"=>["443", "8140", "61613", "8080", "8081"]}],
  #     "creationTimestamp"=>"2019-08-02T08:56:40.846-07:00",
  #     "description"=>"",
  #     "direction"=>"INGRESS",
  #     "disabled"=>false,
  #     "id"=>"7790042981677523927",
  #     "kind"=>"compute#firewall",
  #     "logConfig"=>{"enable"=>false},
  #     "name"=>"beaker-123456-instance-1",
  #     "network"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default",
  #     "priority"=>1000,
  #     "selfLink"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/firewalls/beaker-123456-instance-1",
  #     "sourceRanges"=>["0.0.0.0/0"]},
  #    {"allowed"=>[{"IPProtocol"=>"icmp"}],
  #     "creationTimestamp"=>"2019-05-23T12:36:53.891-07:00",
  #     "description"=>"Allow ICMP from anywhere",
  #     "direction"=>"INGRESS",
  #     "disabled"=>false,
  #     "id"=>"3048688464582887610",
  #     "kind"=>"compute#firewall",
  #     "logConfig"=>{"enable"=>false},
  #     "name"=>"default-allow-icmp",
  #     "network"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default",
  #     "priority"=>65534,
  #     "selfLink"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/firewalls/default-allow-icmp",
  #     "sourceRanges"=>["0.0.0.0/0"]},
  #    {"allowed"=>[{"IPProtocol"=>"tcp", "ports"=>["3389"]}],
  #     "creationTimestamp"=>"2019-05-23T12:36:53.824-07:00",
  #     "description"=>"Allow RDP from anywhere",
  #     "direction"=>"INGRESS",
  #     "disabled"=>false,
  #     "id"=>"2336812744965834938",
  #     "kind"=>"compute#firewall",
  #     "logConfig"=>{"enable"=>false},
  #     "name"=>"default-allow-rdp",
  #     "network"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default",
  #     "priority"=>65534,
  #     "selfLink"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/firewalls/default-allow-rdp",
  #     "sourceRanges"=>["0.0.0.0/0"]},
  #    {"allowed"=>[{"IPProtocol"=>"tcp", "ports"=>["22"]}],
  #     "creationTimestamp"=>"2019-05-23T12:36:53.757-07:00",
  #     "description"=>"Allow SSH from anywhere",
  #     "direction"=>"INGRESS",
  #     "disabled"=>false,
  #     "id"=>"6573848070378440890",
  #     "kind"=>"compute#firewall",
  #     "logConfig"=>{"enable"=>false},
  #     "name"=>"default-allow-ssh",
  #     "network"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default",
  #     "priority"=>65534,
  #     "selfLink"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/firewalls/default-allow-ssh",
  #     "sourceRanges"=>["0.0.0.0/0"]}]
  describe '#list_firewalls' do
    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'returns a hash with a GCE Array of firewall rules' do
      g = gch
      VCR.use_cassette('google_compute_helper/firewall_list_req', match_requests_on: %i[method uri]) do
        expect(g.list_firewalls(start, attempts)).to be_kind_of(Array)
      end
    end
  end

  # {
  #   :api_method => #<Google::APIClient::Method:0x3fccfb9d1504 ID:compute.firewalls.delete>,
  #   :parameters => {"firewall"=>"beaker-tmp-instance", "project"=>"beaker-compute", "zone"=>"us-central1-a"},
  # }
  describe '#firewall_delete_req' do
    let(:name) { 'beaker-firewall-delete-req' }

    it 'retuns a firewall deletion request hash object' do
      g = gch
      VCR.use_cassette('google_compute_helper/firewall_delete_req', match_requests_on: %i[method uri body]) do
        expect(g.firewall_delete_req(name)).to be_kind_of(Hash)
      end
    end
  end

  describe '#delete_firewall' do
    let(:name) { 'beaker-delete-firewall' }
    let(:network) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default' }
    end
    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'deletes an existing firewall rule' do
      g = gch
      VCR.use_cassette('google_compute_helper/delete_firewall', match_requests_on: %i[method uri]) do
        gch.create_firewall(name, network, start, attempts)

        expect do
          expect(g.delete_firewall(name, start, attempts))
        end.to_not raise_error
      end
    end
  end
end
