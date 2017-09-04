if Gem::Version.new(Rails.version) >= Gem::Version.new("5.0.0")
module ApplicationCable
  class Connection < ActionCable::Connection::Base
  end
end
end
