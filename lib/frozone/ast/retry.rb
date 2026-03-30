require_relative 'node'

module Frozone
  module Ast
    class RetryException < StandardError; end

    class Retry < Node
      def evaluate(_context) = raise RetryException
    end
  end
end
