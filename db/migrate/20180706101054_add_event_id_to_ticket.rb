class AddEventIdToTicket < ActiveRecord::Migration[5.0]
  def change
    add_column :tickets, :event_id, :integer
  end
end
