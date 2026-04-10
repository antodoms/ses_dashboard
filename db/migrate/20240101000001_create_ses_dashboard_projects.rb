class CreateSesDashboardProjects < ActiveRecord::Migration[7.0]
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
