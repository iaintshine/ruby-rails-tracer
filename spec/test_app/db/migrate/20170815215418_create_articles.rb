superclass = if Gem::Version.new(Rails.version) >= Gem::Version.new(5)
              ActiveRecord::Migration[5.0]
            else
              ActiveRecord::Migration
            end

class CreateArticles < superclass
  def change
    create_table :articles do |t|
      t.string :title
      t.text :text

      t.timestamps
    end
  end
end
