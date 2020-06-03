# frozen_string_literal: true

require 'simplecov'
require 'beaker'
require 'fakefs/spec_helpers'
require 'webmock/rspec'
require 'vcr'
require 'helpers'
require 'mocks'

# load beaker-google lib files
Dir.glob(Dir.pwd + '/lib/beaker/hypervisor/*.rb') { |file| require file }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Run only these specs
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  # load custom beaker helpers
  config.include HostHelpers
  config.include FSMocks
  config.include GoogleApiMocks
end

# https://relishapp.com/vcr/vcr/docs
VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  # config.debug_logger = File.open('vcr.log', 'w')
end
