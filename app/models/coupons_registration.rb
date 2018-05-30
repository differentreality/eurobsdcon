class CouponsRegistration < ApplicationRecord
  has_paper_trail on: [:create, :destroy], meta: { conference_id: :conference_id }

  belongs_to :coupon
  belongs_to :registration

  validates :coupon_id, uniqueness: { scope: :registration_id }

  # same conference for coupon and registration

  private

  def conference_id
    registration.conference_id
  end
end
