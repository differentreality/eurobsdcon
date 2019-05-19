# frozen_string_literal: true

class TicketGroup < ApplicationRecord
  belongs_to :conference
  has_many :tickets

  validates :name, presence: true
end
