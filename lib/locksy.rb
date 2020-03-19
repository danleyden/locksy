require 'logger'

module Locksy
  def self.logger=(value)
    @logger = value
  end

  def self.logger
    @logger ||= ::Logger.new(STDOUT)
  end
end
