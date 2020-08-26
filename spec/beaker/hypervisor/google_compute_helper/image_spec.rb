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
end
