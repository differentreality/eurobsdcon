require 'spec_helper'

describe 'Coupon' do
  subject { create(:coupon) }
  let!(:conference) { create(:conference) }
  let(:coupon) { create(:coupon, conference: conference) }
  let(:registration) { create(:registration, conference: conference) }
  let(:extra_registration) { create(:registration, conference: conference) }

  describe 'validation' do
    it 'has a valid factory' do
      expect(build(:coupon)).to be_valid
    end

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:discount_type) }
    it { is_expected.to validate_presence_of(:discount_amount) }
    it { is_expected.to validate_presence_of(:conference_id) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:conference_id) }

    context '#start_time_before_end_time' do
      it 'returns false when start_time to be after end_time' do
        coupon.start_time = Date.current
        coupon.end_time = Date.current - 1
        expect(coupon.valid?).to eq false
      end

      it 'returns true when start_time and end_time are not set' do
        coupon.start_time = nil
        coupon.end_time = nil
        expect(coupon.valid?).to eq true
      end

      it 'returns true when start_time is before end_time' do
        coupon.start_time = Date.current - 1
        coupon.end_time = Date.current + 1
        expect(coupon.valid?).to eq true
      end

      it 'returns true when start_time is nil' do
        coupon.start_time = nil
        coupon.end_time = Date.current + 1
        expect(coupon.valid?).to eq true
      end
    end

    describe '#reduce_max_times_if_no_more_registrations' do
      it 'returns true when there are not more registrations than max_times' do
        coupon.max_times = 2
        coupon.registration_ids = [registration.id]

        expect(coupon.valid?).to eq true
      end

      it 'returns true when max_times 0' do
        coupon.max_times = 2
        coupon.registration_ids = [registration.id, extra_registration.id]
        coupon.max_times = 0
        expect(coupon.valid?).to eq true
      end

      it 'returns false when there are more registration than max_times' do
        coupon.max_times = 2
        coupon.registration_ids = [registration.id, extra_registration.id]
        coupon.max_times = 1
        expect(coupon.valid?).to eq false
      end
    end
  end

  describe 'association' do
    it { is_expected.to belong_to(:conference) }
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to have_many(:coupons_registrations) }
    it { is_expected.to have_many(:registrations).through(:coupons_registrations) }
  end

  describe 'remaining?' do
    it 'returns false when used max_times' do
      coupon.max_times = 1
      registration.coupons << coupon
      expect(coupon.remaining?).to eq false
    end

    it 'returns true when used less than max_times' do
      coupon.max_times = 2
      registration.coupons << coupon
      coupon.save
      coupon.reload
      expect(coupon.remaining?).to eq true
    end

    it 'returns true when coupon is not used' do
      coupon.max_times = 2
      expect(coupon.remaining?).to eq true
    end

    it 'returns true when coupon max_times is not set' do
      coupon.max_times = 0
      expect(coupon.remaining?).to eq true
    end
  end

  describe 'within_time_period?' do
    before :each do
      start_time = Time.current
      end_time = Time.current
    end

    context 'returns true' do
      it 'when date is same as start_time' do
        expect(coupon.within_time_period?).to eq true
      end

      it 'when date is same as end_time' do
        expect(coupon.within_time_period?).to eq true
      end

      it 'when date is within start and end times' do
        start_date = Date.current - 1
        end_date = Date.current + 1
      end
    end

    context 'returns false' do
      it 'when date is before start_time' do
        start_date = Date.current + 1
        end_date = Date.current + 2
      end

      it 'when date is after end_time' do
        start_date = Date.current - 2
        end_date = Date.current - 1
      end
    end
  end
end
