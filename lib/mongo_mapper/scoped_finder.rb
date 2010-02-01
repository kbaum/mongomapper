module MongoMapper
  class ScopedFinder
    include Enumerable
    
    attr_reader :model, :options
    
    delegate :[], :each, :to_a, :to => :records
    
    def initialize(model, options = {})
      @model = model
      @options = FinderOptions.new(@model, options)
    end
    
    def proxy_options
      @proxy_options ||= options.to_hash
    end
    
    def records
      @records ||= model.send :find_many, proxy_options
    end
    alias :to_a :records
    
    def count
      @count ||= model.count(options.to_hash)
    end
    alias :size :count
    
    def empty?
      if @records
        @records.empty?
      else
        count == 0
      end
    end
    
    def ==(other)
      case other
      when ScopedFinder
        @model == other.model && proxy_options == other.proxy_options
      else
        records == other
      end
    end
    
    def all(options = {})
      if options.empty?
        self
      else
        scoped(options)
      end
    end
    
    def scoped(options = {})
      self.class.new model, @options.compose(FinderOptions.new(model, options))
    end
    
    def method_missing(method, *args)
      if model.has_scope?(method)
        model.send method, args
      else
        records.send method, *args
      end
    end
  end
end