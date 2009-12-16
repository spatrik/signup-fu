class AddGettingStartedToEvents < ActiveRecord::Migration
  def self.up
    add_column :events, :getting_started_dismissed, :boolean, :null => false, :default => 0
  end

  def self.down
    remove_column :events, :getting_started_dismissed
  end
end