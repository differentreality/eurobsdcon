class Coupon < ApplicationRecord
  has_paper_trail ignore: [:updated_at], meta: { conference_id: :conference_id }

  belongs_to :conference
  belongs_to :ticket

  has_many :coupons_registrations
  has_many :registrations, through: :coupons_registrations, dependent: :destroy

  enum discount_type: [:percent, :value]

  validates :name, :discount_amount, :discount_type, :conference_id, presence: true
  validates :name, uniqueness: { scope: :conference_id }
  validate :start_time_before_end_time
  validate :reduce_max_times_if_no_more_registrations

  def available?
    remaining? && within_time_period?
  end

  ##
  # Check if the coupon can still be applied
  # based on the number of times it has been used
  # ==== Returns
  # * +True+ -> If coupon has been applied less than max_times, or max_times are not defined (are 0)
  # * +False+ -> If coupon has already been applied for max_times
  def remaining?
    return true if max_times.zero?
    registrations.count < max_times
  end

  ##
  # Check if we are within the validity period of the coupon
  # ==== Returns
  # * +True+ -> If we are within the defined time period, or if times are not set
  # * +False+ -> If we are outside the defined time period
  def within_time_period?
    return true unless start_time || end_time

    if start_time && end_time
      (start_time..end_time).cover? Time.current
    elsif start_time
      Time.current >= start_time
    elsif end_time
      Time.current <= end_time
    end
  end

  ##
  # Check if coupon dates are in logical order (start_date before end_date)
  # ==== Returns
  # * +True+ -> If start_date is before end_date, or if dates are not set
  # * +False+ -> If enddate is before start_date
  def start_time_before_end_time
    return true unless start_time && end_time

    errors.add(:start_time, 'must be before end time') unless start_time < end_time
  end

  ##
  # Reduce the value of max_times
  # only if there aren't more registration than the new lower value
  def reduce_max_times_if_no_more_registrations
    errors.add(:max_times, 'already has more registrations') if max_times_changed? && max_times < registrations.count && max_times != 0
  end
end
