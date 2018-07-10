class AddDatesToTickets < ActiveRecord::Migration[5.0]
  def change
    add_column :tickets, :start_date, :datetime
    add_column :tickets, :end_date, :datetime
  end
end
