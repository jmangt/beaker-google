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
end
