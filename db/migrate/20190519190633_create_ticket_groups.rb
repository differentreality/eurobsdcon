class CreateTicketGroups < ActiveRecord::Migration[5.0]
  def change
    create_table :ticket_groups do |t|
      t.string :name
      t.float :vat_percent
      t.references :conference
    end
  end
end
