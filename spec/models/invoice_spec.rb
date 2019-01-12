require 'spec_helper'

describe 'Invoice' do
  subject { create(:invoice) }
  let!(:conference) { create(:conference) }

  describe 'validation' do
    it 'has a valid factory' do
      expect(build(:invoice)).to be_valid
    end

    it { is_expected.to validate_presence_of(:no) }
    it { is_expected.to validate_presence_of(:payable) }
    it { is_expected.to validate_presence_of(:vat) }
    it { is_expected.to validate_presence_of(:conference_id) }
    it { is_expected.to validate_uniqueness_of(:no).scoped_to(:conference_id) }
  end

  describe 'association' do
    it { is_expected.to belong_to(:conference) }
    it { is_expected.to belong_to(:payment) }
  end
end
