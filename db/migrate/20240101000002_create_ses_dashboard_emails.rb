class CreateSesDashboardEmails < ActiveRecord::Migration[7.0]
  def change
    create_table :ses_dashboard_emails do |t|
      t.references :project,    null: false, foreign_key: { to_table: :ses_dashboard_projects }
      t.string     :message_id, null: false
      t.text       :destination, null: false  # JSON-serialized array of recipient addresses
      t.string     :source,      null: false  # From: address
      t.string     :subject
      t.string     :status,      null: false, default: "sent"
      t.integer    :opens,       null: false, default: 0
      t.integer    :clicks,      null: false, default: 0
      t.datetime   :sent_at

      t.timestamps
    end

    add_index :ses_dashboard_emails, :message_id, unique: true
    add_index :ses_dashboard_emails, :status
    add_index :ses_dashboard_emails, [:project_id, :sent_at]
  end
end
