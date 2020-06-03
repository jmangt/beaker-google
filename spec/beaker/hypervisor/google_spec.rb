# frozen_string_literal: true

require 'spec_helper'

describe Beaker::Google do
  let(:target) { Beaker::Google }

  context '.new' do
    it 'returns a new instance of Beaker::Google' do
      expect(target.new).to be_instance_of(Beaker::Google)
    end
  end
end
