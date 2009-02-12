class AddLastNotificationMigration < ActiveRecord::Migration
  def self.up
    add_column :videos, :last_notification_at, :datetime
  end

  def self.down
    remove_column :videos, :last_notification_at
  end
end
