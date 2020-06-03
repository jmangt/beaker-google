# frozen_string_literal: true

require 'github_changelog_generator/task'

namespace :changelog do
  # Gets the github token needed for github_changelog_generator
  # - from env var CHANGELOG_GITHUB_TOKEN
  # - if unset, will be limited in number of queries allowed to github
  # - setup a token at https://github.com/settings/tokens
  def github_token
    ENV['CHANGELOG_GITHUB_TOKEN']
  end

  GitHubChangelogGenerator::RakeTask.new :full do |config|
    config.token = github_token
    config.user = 'puppetlabs'
    config.project = 'beaker-aws'
    # Sets next version in the changelog
    # - if unset, newest changes will be listed as 'unreleased'
    # - setting this value directly sets section title on newest changes
    config.future_release = ENV['NEW_VERSION'] unless ENV['NEW_VERSION'].nil?
  end

  GitHubChangelogGenerator::RakeTask.new :unreleased do |config|
    config.token = github_token
    config.user = 'puppetlabs'
    config.project = 'beaker-aws'
    config.unreleased_only = true
    config.output = '' # blank signals clg to print to output rather than a file
  end
end
