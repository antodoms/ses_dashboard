_migration = begin
  ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"]
rescue ArgumentError
  ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.0"]
end

class CreateSesDashboardProjects < _migration
  def change
    create_table :ses_dashboard_projects do |t|
      t.string :name,        null: false
      t.string :token,       null: false
      t.text   :description

      t.timestamps
    end

    add_index :ses_dashboard_projects, :token, unique: true
  end
end
