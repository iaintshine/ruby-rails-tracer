if Gem::Version.new(Rails.version) >= Gem::Version.new("5.0.0")
module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
end
