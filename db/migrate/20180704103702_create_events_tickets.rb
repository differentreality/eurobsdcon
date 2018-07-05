class CreateEventsTickets < ActiveRecord::Migration[5.0]
  def change
    create_table :events_tickets do |t|
      t.integer :ticket_id
      t.integer :event_id
    end
  end
end
