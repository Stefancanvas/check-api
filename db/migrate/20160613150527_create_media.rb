class CreateMedia < ActiveRecord::Migration
  def change
    create_table :media do |t|
      t.belongs_to :user
      t.belongs_to :project, index: true
      t.belongs_to :account, index: true
      t.string :url
      if ActiveRecord::Base.connection.class.name === 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter'
        t.json :data
      else
        t.text :data
      end
      t.timestamps null: false
    end
  end
end
