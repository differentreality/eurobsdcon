class CouponsRegistration < ApplicationRecord
  has_paper_trail on: [:create, :destroy], meta: { conference_id: :conference_id }

  belongs_to :coupon
  belongs_to :registration

  validates :coupon_id, uniqueness: { scope: :registration_id }

  validate :applied_before_conference

  validate :validity

  ##
  # Check if a coupon can still be applied
  # According to time period and the max_times it can be used
  # ====Returns
  # * +True+ -> If we are within the allowed time period
  #             and coupon can still be applied
  # * validation error -> (with proper message) If one of the checks fails
  def validity
    return true if coupon.available?

    errors.add(:base, 'None left!') unless coupon.remaining?
    errors.add(:base, 'Outside of time period.') unless coupon.within_time_period?
  end

  private

  def applied_before_conference
    errors
    .add(:base, "can't apply coupon after the conference") if Date.current > coupon.conference.end_date
  end

  def conference_id
    registration.conference_id
  end
end
