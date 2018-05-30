require 'spec_helper'

describe 'Coupon' do
  subject { create(:coupon) }
  let!(:conference) { create(:conference) }

  describe 'validation' do
    it 'has a valid factory' do
      expect(build(:coupon)).to be_valid
    end

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:discount_type) }
    it { is_expected.to validate_presence_of(:discount_amount) }
    it { is_expected.to validate_presence_of(:conference_id) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:conference_id) }
  end

  describe 'association' do
    it { is_expected.to belong_to(:conference) }
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to have_many(:coupons_registrations) }
    it { is_expected.to have_many(:registrations).through(:coupons_registrations) }
  end
end
