# ProjectHanlon Policy Base class
# Root abstract
require 'policy/base'

module ProjectHanlon
  module PolicyTemplate
    class DiscoverOnly < ProjectHanlon::PolicyTemplate::Base
      include(ProjectHanlon::Logging)

      # @param hash [Hash]
      def initialize(hash)
        super(hash)
        @hidden = false
        @template = :discover_only
        @description = "Policy used to discover new nodes."

        from_hash(hash) unless hash == nil
      end


      def mk_call(node)
        if vmodel && vmodel.current_state != vmodel.final_state
          vmodel.mk_call(node, @uuid)
        elsif model
          model.mk_call(node, @uuid)
        end
      end

      def boot_call(node)
        if vmodel && vmodel.current_state != vmodel.final_state
          vmodel.boot_call(node, @uuid)
        elsif model
          model.boot_call(node, @uuid)
        end
      end

    end
  end
end
