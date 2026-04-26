_migration = begin
  ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"]
rescue ArgumentError
  ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.0"]
end

class CreateSesDashboardEmailEvents < _migration
  def change
    create_table :ses_dashboard_email_events do |t|
      t.references :email,      null: false, foreign_key: { to_table: :ses_dashboard_emails }
      t.string     :event_type, null: false
      t.text       :event_data               # JSON blob of the full SNS notification payload
      t.datetime   :occurred_at, null: false

      t.timestamps
    end

    add_index :ses_dashboard_email_events, [:email_id, :event_type]
    add_index :ses_dashboard_email_events, :occurred_at
  end
end
