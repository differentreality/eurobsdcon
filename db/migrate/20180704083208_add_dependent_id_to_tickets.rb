class AddDependentIdToTickets < ActiveRecord::Migration[5.0]
  def change
    add_column :tickets, :dependent_id, :integer
  end
end
