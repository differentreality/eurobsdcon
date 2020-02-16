class AddBadgeTextToRegistrations < ActiveRecord::Migration[5.2]
  def change
    add_column :registrations, :badge_text, :text
  end
end
