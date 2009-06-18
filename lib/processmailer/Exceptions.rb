module ProcessMailer
    module Exceptions
        class InvalidType
            attr_reader :expected
            attr_reader :received
            def initialize(e,r)
                @expected = e
                @received = r
            end
            def to_s
                "Expected type: #{e}. Received type: #{r}"
            end
        end
        class EmptyParameters
            def to_s
                'Parameters passed are empty'
            end
        end
        def Resync
        end
    end
end