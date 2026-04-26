_migration = begin
  ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"]
rescue ArgumentError
  ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.0"]
end

class AddWebhookForwardsToSesDashboardProjects < _migration
  def change
    add_column :ses_dashboard_projects, :webhook_forwards, :text
  end
end
