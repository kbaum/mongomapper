module MongoMapper
  module Plugins
    module Scopes
      module ClassMethods
        def all(options={})
          ScopedFinder.new(self, options)
        end
        
        def scoped(options={})
          all(options)
        end
        
        def method_missing(method, *args)
          case method.to_s
          when /^scoped_by_(.*)$/
            send :"find_all_by_#{$1}", *args
          else
            super
          end
        end
      end
    end
  end
end