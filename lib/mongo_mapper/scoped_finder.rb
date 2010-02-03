module MongoMapper
  class ScopedFinder
    include Enumerable
    
    attr_reader :model, :options
    
    delegate :[], :each, :to_a, :to_ary, :inspect, :to => :records
    delegate :has_scope?, :to => :model
    
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
    
    def first(options = {})
      scoped(options).limit(1).to_a.first
    end
    
    def scoped(options = {})
      self.class.new model, @options.compose(FinderOptions.new(model, options))
    end
    
    def method_missing(method, *args)
      if has_scope?(method)
        model.send(method, *args).all(proxy_options)
      else
        records.send method, *args
      end
    end
    
    (FinderOptions::OptionKeys - [ :select ]).each do |key|
      class_eval <<-EOS
        def #{key}(value)
          scoped :#{key} => value
        end
      EOS
    end
  end
end