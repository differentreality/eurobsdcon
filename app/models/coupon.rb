class Coupon < ApplicationRecord
  has_paper_trail ignore: [:updated_at], meta: { conference_id: :conference_id }

  belongs_to :conference
  belongs_to :ticket

  has_many :coupons_registrations
  has_many :registrations, through: :coupons_registrations

  enum discount_type: [:percent, :value]

  validates :name, :discount_amount, :discount_type, :conference_id, presence: true
  validates :name, uniqueness: { scope: :conference_id }
end
