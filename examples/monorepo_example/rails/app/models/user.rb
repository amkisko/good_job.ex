class User
  include ActiveModel::Model
  include GlobalID::Identification

  # Simple model for testing GlobalID resolution
  # In a real app, this would have a database table
  # For testing, we'll use a simple in-memory representation
  
  def self.find(id)
    # For testing purposes, create a simple user object
    # In production, this would query the database
    User.new(id: id, name: "User #{id}")
  end

  attr_accessor :id, :name

  def initialize(attributes = {})
    @id = attributes[:id]
    @name = attributes[:name]
  end

  def to_global_id(options = {})
    GlobalID.create(self, options)
  end
end
