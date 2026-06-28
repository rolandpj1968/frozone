# Output of Pass#transfer.
#
# A transfer call can update the visited node itself (pull-side) AND/OR
# write contributions to other nodes (push-side). Most analyses are
# pure push or pure pull; some (notably TI at method-call nodes) are
# bipolar — args push to callee param bindings, return type pulls
# from callee return.
#
#   self_value — new value for the visited node, or nil to leave it
#                unchanged. Used by pull-style transfers (TI) and the
#                pull-side of bipolar transfers.
#   pushes     — Hash[Node → LatticeValue] of contributions to OTHER
#                nodes; empty for pure pull. Used by push-style transfers
#                (Reachability, NA, leaf-class, etc.) and the push-side
#                of bipolar transfers.
#
# Construct via convenience helpers:
#
#   TransferResult.push(pushes_hash)        # pure push pass
#   TransferResult.pull(new_self_value)     # pure pull pass
#   TransferResult.both(self_value:, pushes:)  # bipolar (TI at calls)
#   TransferResult::EMPTY                   # no-op transfer

module Frozone
  module Compiler
    module Analysis
      class TransferResult
        attr_reader :self_value, :pushes

        def initialize(self_value: nil, pushes: {})
          @self_value = self_value
          @pushes = pushes.freeze
        end

        def self.push(pushes) = new(pushes: pushes)
        def self.pull(self_value) = new(self_value: self_value)
        def self.both(self_value:, pushes:) = new(self_value: self_value, pushes: pushes)

        EMPTY = new.freeze
      end
    end
  end
end
