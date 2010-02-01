module MongoMapper
  module Plugins
    module Scopes
      class Scope
        attr_reader :name
        
        def initialize(model, name, options = {})
          @model, @name, @options = model, name, options
        end
        
        def find(*args)
          @model.all(options_for(*args))
        end
        
      private
        def options_for(*args)
          if @options.respond_to? :call
            @options.call(*args)
          else
            # TODO: better support for different argument types
            @options.merge(args.first || {})
          end
        end
      end
      
      module ClassMethods
        def scope(name, options = {})
          scopes[name.to_sym] = Scope.new(self, name, options)
        end
        
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
            if scopes[method]
              scopes[method].find(*args)
            else
              super
            end
          end
        end
        
        def has_scope?(name)
          scopes.key? name.to_sym
        end
        
      protected
        def scopes
          read_inheritable_attribute(:scopes) || write_inheritable_attribute(:scopes, {})
        end
      end
    end
  end
end