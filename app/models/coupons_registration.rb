class CouponsRegistration < ApplicationRecord
  has_paper_trail on: [:create, :destroy], meta: { conference_id: :conference_id }

  belongs_to :coupon
  belongs_to :registration

  validates :coupon_id, uniqueness: { scope: :registration_id }

  validate :applied_before_conference


  private

  def applied_before_conference
    errors
    .add(:base, "can't apply coupon after the conference") if Date.current > coupon.conference.end_date
  end

  def conference_id
    registration.conference_id
  end
end
