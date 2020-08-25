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
  describe '#get_machineType' do
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

  # {:api_method=>#<Google::APIClient::Method:0x3ff636a0bc54 ID:compute.instances.list>, :parameters=>{"project"=>"beaker-compute", "zone"=>"us-central1-a"}}
  describe '#instance_list_req' do
    it 'Creates a Google Comput list instance request' do
      request = gch.instance_list_req
      expect(request).to be_instance_of(Hash)
    end
  end

  describe '#list_instances' do
    let(:start) { Time.now }
    let(:attempts) { 3 }

    it 'returns a hash with a GCE Array of instances' do
      g = gch
      VCR.use_cassette('google_compute_helper/list_instances', match_requests_on: %i[method uri]) do
        expect(g.list_instances(start, attempts)).to be_kind_of(Array)
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
end
