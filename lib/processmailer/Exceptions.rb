module ProcessMailer
    module Exceptions
        class InvalidType < Exception
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
        class EmptyParameters < Exception
            def to_s
                'Parameters passed are empty'
            end
        end
        class Resync < Exception
        end
    end
end