class AddEmailToSponsors < ActiveRecord::Migration[5.0]
  def change
    add_column :sponsors, :email, :string
  end
end
