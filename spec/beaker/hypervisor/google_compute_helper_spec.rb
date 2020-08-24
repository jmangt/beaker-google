# frozen_string_literal: true

require 'spec_helper'
require 'shared_examples'

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
    let(:request) do
      gch.image_list_req(options[:gce_project])
    end

    let(:parameters) do
      { 'project' => 'beaker-compute' }
    end

    it 'Creates a request for listing all images in a project' do
      expect(request).to be_kind_of(Hash)
    end

    it 'returns a valid request object' do
      expect(request.keys).to eql(%i[api_method parameters])
      expect(request[:api_method]).to be_instance_of(Google::APIClient::Method)
      expect(request[:parameters]).to be_instance_of(Hash)
    end

    it 'passes the correct parameters to the request' do
      expect(request[:parameters]).to eql(parameters)
    end
  end

  # <Hash:70210724476060> => {"archiveSizeBytes"=>"16469314560", "creationTimestamp"=>"2019-05-15T19:01:21.060-07:00", "descriptio.../v1/projects/centos-cloud/global/images/centos-7-v20190515", "sourceType"=>"RAW", "status"=>"READY"}
  describe '#get_latest_image' do
    let(:platform) { 'centos-7-x86_64' }
    let(:start) { Time.now }
    let(:attempts) { 3 }

    let(:request) do
      gch.get_latest_image(platform, start, attempts)
    end

    let(:response) do
      %w[kind id creationTimestamp name description sourceType rawDisk status archiveSizeBytes diskSizeGb licenses family selfLink labelFingerprint licenseCodes]
    end

    it 'raises error if no matches are found' do
      stub_image_list_req('all-deprecated')
      expect { request }.to raise_error(RuntimeError, 'Unable to find a single matching image for centos-7-x86_64, found []')
    end

    it 'it returns a single image' do
      stub_image_list_req('centos-7')
      expect(request).to be_instance_of(Hash)
      expect(request.keys).to eql(response)
    end
  end

  # <Hash:70360533969540> => {:api_method=>#<Google::APIClient::Method:0x3ffe154a623c ID:compute.machineTypes.get>, :parameters=>{"machineType"=>"n1-highmem-2", "project"=>"beaker-compute", "zone"=>"us-central1-a"}}
  describe '#machineType_get_req' do
    let(:request) do
      gch.machineType_get_req
    end

    let(:parameters) do
      %w[project zone machineType]
    end

    it 'returns a hash with a GCE get machine type request' do
      VCR.use_cassette('google_compute_helper/machineType_get_req', match_requests_on: %i[method uri body]) do
        expect(request).to be_kind_of(Hash)
      end
    end

    it 'returns a valid request object' do
      VCR.use_cassette('google_compute_helper/machineType_get_req', match_requests_on: %i[method uri body]) do
        expect(request.keys).to eql(%i[api_method parameters])
        expect(request[:api_method]).to be_instance_of(Google::APIClient::Method)
        expect(request[:parameters]).to be_instance_of(Hash)
      end
    end

    it 'passes the correct parameters' do
      VCR.use_cassette('google_compute_helper/machineType_get_req', match_requests_on: %i[method uri body]) do
        expect(request[:parameters].keys).to eql(parameters)
      end
    end
  end

  # <Hash:70360533969540> => {:api_method=>#<Google::APIClient::Method:0x3ffe154a623c ID:compute.machineTypes.get>, :parameters=>{"machineType"=>"n1-highmem-2", "project"=>"beaker-compute", "zone"=>"us-central1-a"}}
  describe '#get_machineType', focus: true do
    let(:start) { Time.now }
    let(:attempts) { 3 }

    let(:request) do
      gch.get_machineType(start, attempts)
    end

    let(:response) do
      %w[id creationTimestamp name description guestCpus memoryMb imageSpaceGb maximumPersistentDisks maximumPersistentDisksSizeGb zone selfLink isSharedCpu kind]
    end

    it 'returns a hash with a GCE get machine type request' do
      VCR.use_cassette('google_compute_helper/machineType_get_req', match_requests_on: %i[method uri body]) do
        expect(request).to be_kind_of(Hash)
      end
    end

    it 'returns the correct fields' do
      VCR.use_cassette('google_compute_helper/machineType_get_req', match_requests_on: %i[method uri body]) do
        expect(request.keys).to eql(response)
      end
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

  # [
  #   {"canIpForward"=>false,
  #     "cpuPlatform"=>"Intel Haswell",
  #     "creationTimestamp"=>"2020-06-03T11:57:21.700-07:00",
  #     "deletionProtection"=>false,
  #     "description"=>"",
  #     "disks"=>
  #      [{"autoDelete"=>true,
  #        "boot"=>true,
  #        "deviceName"=>"instance-1",
  #        "diskSizeGb"=>"10",
  #        "guestOsFeatures"=>
  #         [{"type"=>"VIRTIO_SCSI_MULTIQUEUE"}, {"type"=>"UEFI_COMPATIBLE"}],
  #        "index"=>0,
  #        "interface"=>"SCSI",
  #        "kind"=>"compute#attachedDisk",
  #        "licenses"=>
  #         ["https://www.googleapis.com/compute/v1/projects/debian-cloud/global/licenses/debian-10-buster"],
  #        "mode"=>"READ_WRITE",
  #        "source"=>
  #         "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/disks/instance-1",
  #        "type"=>"PERSISTENT"}],
  #     "displayDevice"=>{"enableDisplay"=>false},
  #     "fingerprint"=>"qWzWA0gRLLM=",
  #     "id"=>"2996968850626071678",
  #     "kind"=>"compute#instance",
  #     "labelFingerprint"=>"42WmSpB8rSM=",
  #     "machineType"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/machineTypes/n1-standard-1",
  #     "metadata"=>{"fingerprint"=>"QifdRPFQkVk=", "kind"=>"compute#metadata"},
  #     "name"=>"instance-1",
  #     "networkInterfaces"=>
  #      [{"accessConfigs"=>
  #         [{"kind"=>"compute#accessConfig",
  #           "name"=>"External NAT",
  #           "natIP"=>"34.71.204.156",
  #           "networkTier"=>"PREMIUM",
  #           "type"=>"ONE_TO_ONE_NAT"}],
  #        "fingerprint"=>"t_TaoevVDNU=",
  #        "kind"=>"compute#networkInterface",
  #        "name"=>"nic0",
  #        "network"=>
  #         "https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default",
  #        "networkIP"=>"10.128.0.6",
  #        "subnetwork"=>
  #         "https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/us-central1/subnetworks/default"}],
  #     "reservationAffinity"=>{"consumeReservationType"=>"ANY_RESERVATION"},
  #     "scheduling"=>
  #      {"automaticRestart"=>true,
  #       "onHostMaintenance"=>"MIGRATE",
  #       "preemptible"=>false},
  #     "selfLink"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/instances/instance-1",
  #     "serviceAccounts"=>
  #      [{"email"=>"961434916749-compute@developer.gserviceaccount.com",
  #        "scopes"=>
  #         ["https://www.googleapis.com/auth/devstorage.read_only",
  #          "https://www.googleapis.com/auth/logging.write",
  #          "https://www.googleapis.com/auth/monitoring.write",
  #          "https://www.googleapis.com/auth/servicecontrol",
  #          "https://www.googleapis.com/auth/service.management.readonly",
  #          "https://www.googleapis.com/auth/trace.append"]}],
  #     "shieldedInstanceConfig"=>
  #      {"enableIntegrityMonitoring"=>true,
  #       "enableSecureBoot"=>false,
  #       "enableVtpm"=>true},
  #     "shieldedInstanceIntegrityPolicy"=>{"updateAutoLearnPolicy"=>true},
  #     "startRestricted"=>false,
  #     "status"=>"RUNNING",
  #     "tags"=>{"fingerprint"=>"42WmSpB8rSM="},
  #     "zone"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a"},
  #   ...
  # ]
  describe '#list_instances' do
    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'returns a hash with a GCE Array of instances' do
      g = gch
      VCR.use_cassette('google_compute_helper/instance_list_req', match_requests_on: %i[method uri]) do
        expect(g.list_instances(start, attempts)).to be_kind_of(Array)
      end
    end
  end

  # [
  #   {"creationTimestamp"=>"2020-06-03T11:57:21.708-07:00",
  #     "guestOsFeatures"=>
  #      [{"type"=>"VIRTIO_SCSI_MULTIQUEUE"}, {"type"=>"UEFI_COMPATIBLE"}],
  #     "id"=>"5642287402060500094",
  #     "kind"=>"compute#disk",
  #     "labelFingerprint"=>"42WmSpB8rSM=",
  #     "lastAttachTimestamp"=>"2020-06-03T11:57:21.708-07:00",
  #     "licenseCodes"=>["5543610867827062957"],
  #     "licenses"=>
  #      ["https://www.googleapis.com/compute/v1/projects/debian-cloud/global/licenses/debian-10-buster"],
  #     "name"=>"instance-1",
  #     "physicalBlockSizeBytes"=>"4096",
  #     "selfLink"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/disks/instance-1",
  #     "sizeGb"=>"10",
  #     "sourceImage"=>
  #      "https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521",
  #     "sourceImageId"=>"3636730682067824323",
  #     "status"=>"READY",
  #     "type"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/diskTypes/pd-standard",
  #     "users"=>
  #      ["https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/instances/instance-1"],
  #     "zone"=>
  #      "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a"},
  #   ...
  # ]
  describe '#list_disks' do
    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'returns a hash with a GCE Array of disks' do
      g = gch
      VCR.use_cassette('google_compute_helper/disk_list_req', match_requests_on: %i[method uri]) do
        expect(g.list_disks(start, attempts)).to be_kind_of(Array)
      end
    end
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

  # {
  #   :api_method => #<Google::APIClient::Method:0x3fce0a83ab54 ID:compute.disks.insert>,
  #   :body_object => {"name"=>"beaker-tmp-disk", "sizeGb"=>25},
  #   :parameters => {"project"=>"beaker-compute", "sourceImage"=>"https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521", "zone"=>"us-central1-a"},
  # }
  describe '#disk_insert_req' do
    let(:name) { 'beaker-tmp-disk' }
    let(:source) { 'https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521' }

    it 'retuns a disk insertion request hash object' do
      g = gch
      VCR.use_cassette('google_compute_helper/disk_insert_req', match_requests_on: %i[method uri body]) do
        expect(g.disk_insert_req(name, source)).to be_kind_of(Hash)
      end
    end
  end

  # {
  #   "creationTimestamp" => "2020-06-03T13:20:43.738-07:00",
  #   "guestOsFeatures" => [{"type"=>"VIRTIO_SCSI_MULTIQUEUE"}, {"type"=>"UEFI_COMPATIBLE"}],
  #   "id" => "659686307143203060",
  #   "kind" => "compute#disk",
  #   "labelFingerprint" => "42WmSpB8rSM=",
  #   "licenseCodes" => ["5543610867827062957"],
  #   "licenses" => ["https://www.googleapis.com/compute/v1/projects/debian-cloud/global/licenses/debian-10-buster"],
  #   "name" => "beaker-tmp-disk",
  #   "physicalBlockSizeBytes" => "4096",
  #   "selfLink" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/disks/beaker-tmp-disk",
  #   "sizeGb" => "25",
  #   "sourceImage" => "https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521",
  #   "sourceImageId" => "3636730682067824323",
  #   "status" => "READY",
  #   "type" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/diskTypes/pd-standard",
  #   "zone" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a",
  # }
  describe '#create_disk' do
    let(:name) { 'beaker-create-disk' }
    let(:img) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521' }
    end
    let(:start) { Time.now }
    let(:attempts) { 3 }

    before(:each) do
      VCR.use_cassette('google_compute_helper/create_disk_before', match_requests_on: %i[method uri]) do
        gch.delete_disk(name, start, attempts)
      end
    rescue
      puts "[WARN] #{name} object not found"
    end

    after(:each) do
      VCR.use_cassette('google_compute_helper/create_disk_after', match_requests_on: %i[method uri]) do
        gch.delete_disk(name, start, attempts)
      end
    rescue
      puts "[WARN] #{name} object not found"
    end

    it 'returns a hash with a GCE disk insertion confirmation' do
      VCR.use_cassette('google_compute_helper/create_disk', match_requests_on: %i[method uri]) do
        expect(gch.create_disk(name, img, start, attempts)).to be_kind_of(Hash)
      end
    end
  end

  # {
  #   :api_method => #<Google::APIClient::Method:0x3fdb163b8888 ID:compute.disks.delete>,
  #   :parameters => {"disk"=>"beaker-tmp-instance", "project"=>"beaker-compute", "zone"=>"us-central1-a"},
  # }
  describe '#disk_delete_req' do
    let(:name) { 'beaker-delete-disk-req' }

    it 'retuns a disk deletion request hash object' do
      g = gch
      VCR.use_cassette('google_compute_helper/disk_delete_req', match_requests_on: %i[method uri body]) do
        expect(g.disk_delete_req(name)).to be_kind_of(Hash)
      end
    end
  end

  describe '#delete_disk' do
    let(:name) { 'beaker-delete-disk' }
    let(:start) { Time.now }
    let(:attempts) { 5 }

    let(:img) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521' }
    end
    let(:start) { Time.now }
    let(:attempts) { 3 }

    before(:each) do
      VCR.use_cassette('google_compute_helper/delete_disk_before', match_requests_on: %i[method uri]) do
        gch.create_disk(name, img, start, attempts)
      end
    rescue
      puts "[WARN] #{name} object already exists"
    end

    # The method just loops until an expection is raised eaither because the disk does not exist anymore
    # or because the we run out of retries
    #
    # Disks can only be deleted if they are no longer attached to a vm
    # You can only detach a disk from a vm that is not running
    it 'waits until disk no longer present then exists' do
      VCR.use_cassette('google_compute_helper/delete_disk', match_requests_on: %i[method uri]) do
        expect do
          gch.delete_disk(name, start, attempts)
        end.to_not raise_error
      end
    end
  end

  # {
  #   api_method: '<Google::APIClient::Method:0x3fc85109de28 ID:compute.instances.insert>,
  #   body_object: {
  #     'disks' => [{ 'boot' => 'true', 'source' => { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/disks/beaker-tmp-disk' }, 'type' => 'PERSISTENT' }],
  #     'image' => { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521' },
  #     'machineType' => { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/machineTypes/n1-standard-1' },
  #     'name' => 'beaker-tmp-instance',
  #     'networkInterfaces' => [{ 'accessConfigs' => [{ 'name' => 'External NAT', 'type' => 'ONE_TO_ONE_NAT' }],
  #     'network' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default' }],
  #     'zone' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/global/zones/us-central1-a'
  #   },
  #   parameters: { 'project' => 'beaker-compute', 'zone' => 'us-central1-a' }
  # }
  describe '#instance_insert_req' do
    let(:name) { 'beaker-tmp-instance' }
    let(:image) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521' }
    end
    let(:machineType) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/machineTypes/n1-standard-1' }
    end
    let(:disk) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/disks/beaker-tmp-disk' }
    end

    it 'retuns a instance insertion request hash object' do
      g = gch
      VCR.use_cassette('google_compute_helper/instance_insert_req', match_requests_on: %i[method uri body]) do
        expect(g.instance_insert_req(name, image, machineType, disk)).to be_kind_of(Hash)
      end
    end
  end

  # {
  #   :api_method => #<Google::APIClient::Method:0x3fe5f04d07cc ID:compute.instances.get>,
  #   :parameters => {"instance"=>"beaker-tmp-instance", "project"=>"beaker-compute", "zone"=>"us-central1-a"},
  # }
  describe '#instance_get_req' do
    let(:name) { 'beaker-tmp-instance' }

    it 'retuns a instance get request hash object' do
      g = gch
      VCR.use_cassette('google_compute_helper/instance_get_req', match_requests_on: %i[method uri body]) do
        expect(g.instance_get_req(name)).to be_kind_of(Hash)
      end
    end
  end

  # {
  #   "cpuPlatform" => "Unknown CPU Platform",
  #   "creationTimestamp" => "2020-06-03T14:03:00.189-07:00",
  #   "deletionProtection" => false,
  #   "disks" => [{"autoDelete"=>false, "boot"=>true, "deviceName"=>"persistent-disk-0", "diskSizeGb"=>"25", "guestOsFeatures"=>[{"type"=>"VIRTIO_SCSI_MULTIQUEUE"}, {"type"=>"UEFI_COMPATIBLE"}], "index"=>0, "interface"=>"SCSI", "kind"=>"compute#attachedDisk", "licenses"=>["https://www.googleapis.com/compute/v1/projects/debian-cloud/global/licenses/debian-10-buster"], "mode"=>"READ_WRITE", "source"=>"https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/disks/beaker-tmp-disk", "type"=>"PERSISTENT"}],
  #   "fingerprint" => "qI0YiRPpgT8=",
  #   "id" => "5700755964386717420",
  #   "kind" => "compute#instance",
  #   "labelFingerprint" => "42WmSpB8rSM=",
  #   "machineType" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/machineTypes/n1-standard-1",
  #   "metadata" => {"fingerprint"=>"QifdRPFQkVk=", "kind"=>"compute#metadata"},
  #   "name" => "beaker-tmp-instance",
  #   "networkInterfaces" => [{"accessConfigs"=>[{"kind"=>"compute#accessConfig", "name"=>"External NAT", "networkTier"=>"PREMIUM", "type"=>"ONE_TO_ONE_NAT"}], "fingerprint"=>"_pa8FAljqwg=", "kind"=>"compute#networkInterface", "name"=>"nic0", "network"=>"https://www.googleapis.com/compute/v1/projects/beaker-compute/global/networks/default", "subnetwork"=>"https://www.googleapis.com/compute/v1/projects/beaker-compute/regions/us-central1/subnetworks/default"}],
  #   "scheduling" => {"automaticRestart"=>true, "onHostMaintenance"=>"MIGRATE", "preemptible"=>false},
  #   "selfLink" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/instances/beaker-tmp-instance",
  #   "shieldedInstanceConfig" => {"enableIntegrityMonitoring"=>true, "enableSecureBoot"=>false, "enableVtpm"=>true},
  #   "shieldedInstanceIntegrityPolicy" => {"updateAutoLearnPolicy"=>true},
  #   "startRestricted" => false,
  #   "status" => "PROVISIONING",
  #   "tags" => {"fingerprint"=>"42WmSpB8rSM="},
  #   "zone" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a",
  # }
  describe '#create_instance' do
    let(:name) { 'beaker-tmp-instance' }
    let(:image) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521' }
    end
    let(:img) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-10-buster-v20200521' }
    end
    let(:machineType) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/machineTypes/n1-standard-1' }
    end
    let(:disk) do
      { 'selfLink' => 'https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/disks/beaker-tmp-disk' }
    end

    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'returns a hash with a GCE instance creation confirmation' do
      g = gch
      VCR.use_cassette('google_compute_helper/create_instance', match_requests_on: %i[method uri]) do
        expect(g.create_instance(name, img, machineType, disk, start, attempts)).to be_kind_of(Hash)
      end
    end
  end

  # {
  #  :api_method => #<Google::APIClient::Method:0x3fdc4f045c5c ID:compute.instances.setMetadata>,
  #  :body_object => {
  #    "fingerprint"=>"qI0YiRPpgT8=",
  #    "items"=>[
  #      {:key=>:department, :value=>"beaker"},
  #      {:key=>:project, :value=>"beaker-compute"},
  #      {:key=>:jenkins_build_url, :value=>"https://jenkins.io"},
  #      {:key=>:sshKeys, :value=>"google_compute:abcd123"}
  #     ],
  #    "kind"=>"compute#metadata"
  #   },
  #  :parameters => {
  #    "instance"=>"beaker-tmp-instance",
  #    "project"=>"beaker-compute",
  #    "zone"=>"us-central1-a"
  #   }
  # }
  describe '#instance_setMetadata_req' do
    let(:name) { 'beaker-tmp-instance' }
    let(:fingerprint) { 'qI0YiRPpgT8=' }
    let(:data) do
      [{ key: :department, value: 'beaker' },
       { key: :project, value: 'beaker-compute' },
       { key: :jenkins_build_url, value: 'https://jenkins.io' },
       { key: :sshKeys, value: 'google_compute:abcd123' }]
    end

    it 'returns a hash with a GCE set metadata request' do
      g = gch
      VCR.use_cassette('google_compute_helper/instance_setmetadata_req', match_requests_on: %i[method uri]) do
        expect(g.instance_setMetadata_req(name, fingerprint, data)).to be_kind_of(Hash)
      end
    end
  end

  # {
  #   :api_method => #<Google::APIClient::Method:0x3fbf5c4eb0b4 ID:compute.zoneOperations.get>,
  #   :parameters => {"operation"=>"foo", "project"=>"beaker-compute", "zone"=>"us-central1-a"},
  # }
  describe '#operation_get_req' do
    let(:zone_operation) do
      { 'id' => '1174395149241282414',
        'name' => 'operation-1591366017070-5a756c627b604-fa94900f-83e77802',
        'zone' =>
         'https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a',
        'operationType' => 'setMetadata',
        'targetLink' =>
         'https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/instances/beaker-tmp-instance',
        'targetId' => '5700755964386717420',
        'status' => 'RUNNING',
        'user' => 'beaker-compute@beaker-compute.iam.gserviceaccount.com',
        'progress' => 0,
        'insertTime' => '2020-06-05T07:06:57.596-07:00',
        'startTime' => '2020-06-05T07:06:57.620-07:00',
        'selfLink' =>
         'https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/operations/operation-1591366017070-5a756c627b604-fa94900f-83e77802',
        'kind' => 'compute#operation' }
    end

    it 'returns a hash with a GCE zone operation request' do
      g = gch
      VCR.use_cassette('google_compute_helper/operation_get_req', match_requests_on: %i[method uri]) do
        expect(g.operation_get_req(zone_operation['name'])).to be_kind_of(Hash)
      end
    end
  end

  # {
  #   "id" => "1174395149241282414",
  #   "insertTime" => "2020-06-05T07:06:57.596-07:00",
  #   "kind" => "compute#operation",
  #   "name" => "operation-1591366017070-5a756c627b604-fa94900f-83e77802",
  #   "operationType" => "setMetadata",
  #   "progress" => 0,
  #   "selfLink" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/operations/operation-1591366017070-5a756c627b604-fa94900f-83e77802",
  #   "startTime" => "2020-06-05T07:06:57.620-07:00",
  #   "status" => "RUNNING",
  #   "targetId" => "5700755964386717420",
  #   "targetLink" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a/instances/beaker-tmp-instance",
  #   "user" => "beaker-compute@beaker-compute.iam.gserviceaccount.com",
  #   "zone" => "https://www.googleapis.com/compute/v1/projects/beaker-compute/zones/us-central1-a",
  # }
  describe '#setMetadata_on_instance' do
    let(:name) { 'beaker-tmp-instance' }
    let(:fingerprint) { 'QifdRPFQkVk=' }
    let(:data) do
      [{ key: :department, value: 'beaker' },
       { key: :project, value: 'beaker-compute' },
       { key: :jenkins_build_url, value: 'https://jenkins.io' },
       { key: :sshKeys, value: 'google_compute:abcd123' }]
    end
    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'returns a hash with a GCE zone operation response' do
      g = gch
      VCR.use_cassette('google_compute_helper/setMetadata_on_instance', match_requests_on: %i[method uri]) do
        expect(g.setMetadata_on_instance(name, fingerprint, data, start, attempts)).to be_kind_of(Hash)
      end
    end
  end

  # {
  #   :api_method => #<Google::APIClient::Method:0x3ff0cd09407c ID:compute.instances.delete>,
  #   :parameters => {"instance"=>"beaker-tmp-instance", "project"=>"beaker-compute", "zone"=>"us-central1-a"},
  # }
  describe '#instance_delete_req' do
    let(:name) { 'beaker-tmp-instance' }

    it 'retuns a instance deletion request hash object' do
      g = gch
      VCR.use_cassette('google_compute_helper/instance_delete_req', match_requests_on: %i[method uri body]) do
        expect(g.instance_delete_req(name)).to be_kind_of(Hash)
      end
    end
  end

  describe '#delete_instance' do
    let(:name) { 'beaker-tmp-instance' }
    let(:start) { Time.now }
    let(:attempts) { 1 }

    # the method just loops until an expection is raised
    # eaither because the instance does not exist anymore
    # or because the we run out of retries
    it 'waits until instance no longer exists then exists' do
      g = gch
      VCR.use_cassette('google_compute_helper/delete_instance', match_requests_on: %i[method uri]) do
        expect do
          g.delete_instance(name, start, attempts)
        end.to_not raise_error
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

  # {:api_method=>#<Google::APIClient::Method:0x3ff636a0bc54 ID:compute.instances.list>, :parameters=>{"project"=>"beaker-compute", "zone"=>"us-central1-a"}}
  describe '#instance_list_req' do
    it 'Creates a Google Comput list instance request' do
      request = gch.instance_list_req
      expect(request).to be_instance_of(Hash)
    end
  end
end
