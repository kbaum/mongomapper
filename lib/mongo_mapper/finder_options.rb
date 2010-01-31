module MongoMapper
  # = Important Note
  # This class is private to MongoMapper and should not be considered part of 
  # MongoMapper's public API.
  #
  class FinderOptions
    OptionKeys = [:fields, :select, :skip, :offset, :limit, :sort, :order]

    def self.normalized_field(field)
      field.to_s == 'id' ? :_id : field
    end

    def self.normalized_order_direction(direction)
      direction ||= 'ASC'
      direction.upcase == 'ASC' ? 1 : -1
    end

    def initialize(model, options)
      raise ArgumentError, "Options must be a hash" unless options.is_a?(Hash)

      @model      = model
      @options    = {}
      @conditions = {}

      options.each_pair do |key, value|
        key = key.respond_to?(:to_sym) ? key.to_sym : key
        if OptionKeys.include?(key)
          @options[key] = value
        elsif key == :conditions
          @conditions.merge!(value)
        else
          @conditions[key] = value
        end
      end

      add_sci_scope
    end

    def criteria
      to_mongo_criteria(@conditions)
    end

    def options
      fields = @options[:fields] || @options[:select]
      skip   = @options[:skip]   || @options[:offset] || 0
      limit  = @options[:limit]  || 0
      sort   = @options[:sort]   || convert_order_to_sort(@options[:order])

      {:fields => to_mongo_fields(fields), :skip => skip.to_i, :limit => limit.to_i, :sort => sort}
    end

    def to_a
      [criteria, options]
    end
    
    def compose(other)
      return other.dup if criteria.empty? && options.empty?
            
      hash = criteria.merge options
      c, o = other.criteria, other.options
      
      hash[:fields] = (Array(hash[:fields]) | o[:fields]) if o[:fields]
      hash[:skip]   = o[:skip] if o[:skip]
      hash[:limit]  = o[:limit] if o[:limit]
      hash[:sort]   = compose_sort_order(hash[:sort], o[:sort]) if o[:sort]
      
      c.each_pair do |key, value|
        if hash[key].present?
          hash[key] = compose_criteria(hash[key], value)
        else
          hash[key] = value
        end
      end
      
      self.class.new(@model, hash)
    end

    private
      def to_mongo_criteria(conditions, parent_key=nil)
        criteria = {}

        conditions.each_pair do |field, value|
          field = self.class.normalized_field(field)
          
          if @model.object_id_key?(field) && value.is_a?(String)
            value = Mongo::ObjectID.from_string(value)
          end
          
          if field.is_a?(SymbolOperator)
            criteria.update(field.to_mm_criteria(value))
            next
          end
          
          case value
            when Array
              criteria[field] = operator?(field) ? value : {'$in' => value}
            when Hash
              criteria[field] = to_mongo_criteria(value, field)
            when Time
              criteria[field] = value.utc
            else            
              criteria[field] = value
          end
        end

        criteria
      end

      def operator?(field)
        field.to_s =~ /^\$/
      end

      # adds _type single collection inheritance scope for models that need it
      def add_sci_scope
        if @model.single_collection_inherited?
          @conditions[:_type] = @model.to_s
        end
      end

      def to_mongo_fields(fields)
        return if fields.blank?

        if fields.respond_to?(:flatten, :compact)
          fields.flatten.compact
        else
          fields.split(',').map { |field| field.strip }
        end
      end

      def convert_order_to_sort(sort)
        return if sort.blank?
        
        if sort.respond_to?(:all?) && sort.all? { |s| s.respond_to?(:to_mm_order) }
          sort.map { |s| s.to_mm_order }
        elsif sort.respond_to?(:to_mm_order)
          [sort.to_mm_order]
        else
          pieces = sort.split(',')
          pieces.map { |s| to_mongo_sort_piece(s) }
        end
      end

      def to_mongo_sort_piece(str)
        field, direction = str.strip.split(' ')
        direction = FinderOptions.normalized_order_direction(direction)
        [field, direction]
      end
      
      def compose_sort_order(a, b)
        result = Array(a).dup
        b.reverse.each do |field, direction|
          f = field.to_s
          result.reject! { |f, d| f.to_s == field }
          result.unshift [ field, direction ]
        end
        result
      end
      
      def compose_criteria(a, b)
        case b
        when Hash
          case a
          when nil then b.dup
          when Hash
            result = a.dup
            b.each_pair do |key, value|
              case key
              when '$ne'
                if result['$ne'] && (result['$ne'] != value)
                  result['$nin'] = Array(result['$nin']) | [ result.delete('$ne'), value ]
                else
                  result['$ne'] = value
                end
              when '$lt', '$lte'
                # TODO: be smart about $lt and $lte together
                if result[key] && (result[key] != value)
                  result[key] = [ result[key], value ].min
                else
                  result[key] = value
                end
              when '$gt', '$gte'
                # TODO: be smart about $gt and $gte together
                if result[key] && (result[key] != value)
                  result[key] = [ result[key], value ].max
                else
                  result[key] = value
                end
              when '$in'
                result['$in'] = result.key?('$in') ? (result['$in'] & b['$in']) : b['$in']
              when '$nin'
                result['$nin'] = Array(result['$nin']) | value
              when '$mod'
                # TODO: find mathematical way of doing this properly
                result['$mod'] = value
              when '$all', '$size'
                # TODO: these should result in empty result sets if they are different
                result[key] = value
              else
                result[key] = case value
                when Hash then compose_criteria(result[key], value)
                else value
                end
              end
            end
            result
          else
            compose_criteria({ '$in' => [ a ] }, b)
          end
        else
          case a
          when Hash then compose_criteria(b, a)
          else Array(a) & Array(b)
          end
        end
      end
  end
end