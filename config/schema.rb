require 'sequel'

Sequel.connect("sqlite://experiments.db") { |db|
  db.create_table :trials do 
    primary_key :id
    String :name
    String :events, text: true
    String :about, text: true
  end
}

