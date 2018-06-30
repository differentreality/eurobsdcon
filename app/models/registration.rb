# frozen_string_literal: true

class Registration < ApplicationRecord
  require 'csv'
  belongs_to :user
  belongs_to :conference

  has_and_belongs_to_many :qanswers
  has_and_belongs_to_many :vchoices

  has_many :coupons_registrations
  has_many :coupons, through: :coupons_registrations, dependent: :destroy
  has_many :events_registrations
  has_many :events, through: :events_registrations, dependent: :destroy

  has_paper_trail ignore: %i(updated_at week), meta: { conference_id: :conference_id }

  accepts_nested_attributes_for :user
  accepts_nested_attributes_for :qanswers

  delegate :name, to: :user
  delegate :email, to: :user
  delegate :nickname, to: :user
  delegate :affiliation, to: :user
  delegate :username, to: :user

  alias_attribute :other_needs, :other_special_needs

  validates :user, presence: true

  validates :user_id, uniqueness: { scope: :conference_id, message: 'already Registered!' }
  validate :registration_limit_not_exceed, on: :create
  validate :registered_to_non_intersecting_events
  validate :registration_to_events_only_if_present

  validates :accepted_code_of_conduct, acceptance: {
    if: -> { conference.code_of_conduct.present? }
  }

  after_create :set_week, :subscribe_to_conference, :send_registration_mail

  ##
  # Makes a list of events that includes (in that order):
  # Events that require registration, and registration to them is still possible
  # Events to which the user is already registered to
  # ==== RETURNS
  # * +Array+ -> [event_to_register_to, event_already_registered_to]
  def events_ordered
    (conference.program.events.with_registration_open - events) + events
  end

  private

  def registered_to_non_intersecting_events
    result = false
    events_with_time = events.select(&:time)
    events_with_time.each_with_index do |check_event, index|
      remaining_events = events.where.not(id: check_event.id).select(&:time)

      puts "check_event ID #{check_event.id}"
      result = remaining_events.any?{ |event| puts "event ID #{event.id}"; (event.time.to_datetime..(event.time+event.event_type.length.minutes).to_datetime).include? check_event.time.to_datetime }
    end
    errors.add(:base, 'You cannot register to 2 happenings at the same time!') if result
  end

  ##
  # If the user registers to attend events that are already scheduled,
  # only allow registration to events if the user will be present
  # (based on arrival and departure attributes)
  # No validation if arrival/departure attributes are empty
  def registration_to_events_only_if_present
    if (arrival || departure) && events.pluck(:start_time).any?
      errors.add(:arrival, 'is too late! You cannot register for events that take place before your arrival') if events.pluck(:start_time).compact.map { |x| x < arrival }.any?

      errors.add(:departure, 'is too early! You cannot register for events that take place after your departure') if events.pluck(:start_time).compact.map { |x| x > departure }.any?
    end
  end

  def subscribe_to_conference
    Subscription.create(conference_id: conference.id, user_id: user.id)
  end

  def send_registration_mail
    if conference.email_settings.send_on_registration?
      Mailbot.registration_mail(conference, user).deliver_later
    end
  end

  def set_week
    update!(week: created_at.strftime('%W'))
  end

  def registration_limit_not_exceed
    if conference.registration_limit > 0 && conference.registrations(:reload).count >= conference.registration_limit
      errors.add(:base, 'Registration limit exceeded')
    end
  end
end
