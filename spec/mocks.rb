# frozen_string_literal: true

require 'fileutils'
require 'json'

module FSMocks
  def stub_gce_keyfile(options)
    gce_dir = File.join(ENV['HOME'], '.beaker', 'gce')
    keyfile = File.join(gce_dir, %(#{options[:gce_project]}.p12))
    FileUtils.mkdir_p(gce_dir)
    File.open(keyfile, 'w') do |file|
      file.puts('ABC123')
    end
    allow(Google::APIClient::PKCS12).to receive(:load_key).and_return('ABC123')
  end
end

module GoogleApiMocks
  def stub_gcp_authentication(_options)
    # stub_gce_keyfile(options)
    allow_any_instance_of(Beaker::GoogleComputeHelper).to receive(:authenticate).and_return(true)
  end

  def stub_auth2_token_request
    response = {
      'access_token': 'ya29.c.ElooB5uECJo_JmFgfn08swdkRK56kVNvNjT1K4Q_GWGXxhg8jYCN5lEhrJpR3ZSNgOQ95DvdMDlXA3xfDmrtjhafQsb-UyDEklfYrJjoC6k8Z9tFBv9hx2ynhrc',
      'expires_in': 3600,
      'token_type': 'Bearer'
    }.to_json
    stub_request(:post, 'https://accounts.google.com/o/oauth2/token')
      .with(
        body: {
          'assertion' => /[a-z][A-Z][0-9]/,
          'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer'
        },
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/x-www-form-urlencoded',
          'User-Agent' => 'Faraday v0.15.4'
        }
      )
      .to_return(status: 200, body: response, headers: {})
  end

  def stub_image_list_req(data_set = 'all_deprecated')
    data = YAML.load_file("spec/fixtures/compute/image_list/#{data_set}.yml")
    allow_any_instance_of(Beaker::GoogleComputeHelper).to receive(:execute).and_return(data)
  end
end
