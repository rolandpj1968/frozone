# Stub rubygems for Frozone VM -- the real rubygems uses C extensions that Frozone can't run
module Gem
  def self.find_files(*) = []
  def self.find_latest_files(*) = []
  def self.path = []
  def self.dir = ''
  def self.loaded_specs = {}
  class Specification
    def self.flat_map(*) = []
    def self.each(*) = nil
  end
end

module RbConfig
  CONFIG = {}

  def self.ruby = ''
end
