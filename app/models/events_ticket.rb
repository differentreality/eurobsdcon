class EventsTicket < ApplicationRecord
  table_name = 'events_tickets'
  belongs_to :event
  belongs_to :ticket
end
