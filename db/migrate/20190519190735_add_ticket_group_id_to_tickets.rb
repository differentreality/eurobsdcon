class AddTicketGroupIdToTickets < ActiveRecord::Migration[5.0]
  def change
    add_column :tickets, :ticket_group_id, :integer
  end
end
