module ValidatesTimeliness

  # Adds ActiveRecord validation methods for date, time and datetime validation.
  # The validity of values can be restricted to be before and/or certain dates
  # or times.
  module Validations    
    mattr_accessor :valid_time_formats
    mattr_accessor :valid_date_formats
    mattr_accessor :valid_datetime_formats
        
    # Error messages added to AR defaults to allow global override if you need.  
    def self.included(base)
      base.extend ClassMethods
      
      error_messages = {
        :invalid_datetime => "is not a valid %s",
        :before           => "must be before %s",
        :on_or_before     => "must be on or before %s",
        :after            => "must be after %s",
        :on_or_after      => "must be on or after %s"
      }      
      ActiveRecord::Errors.default_error_messages.update(error_messages)
      
      base.class_inheritable_hash :valid_time_formats
      base.class_inheritable_hash :valid_date_formats
      base.class_inheritable_hash :valid_datetime_formats

      base.valid_time_formats = self.valid_time_formats
      base.valid_date_formats = self.valid_date_formats
      base.valid_datetime_formats = self.valid_datetime_formats
    end

   
    # The if you want to combine a time regexp with a date regexp then you
    # should not use line begin or end anchors in the expression. Pre and post
    # match strings are still checked for validity, and fail the match if they
    # are not empty.
    #
    # The proc object should return an array with 1-3 elements with values 
    # ordered like so [hour, minute, second]. The proc should have as many
    # arguments as groups in the regexp or you will get an error.
    self.valid_time_formats = {
      :hhnnss_colons   => /(\d{2}):(\d{2}):(\d{2})/,
      :hhnnss_dashes   => /(\d{2})-(\d{2})-(\d{2})/,
      :hhnn_colons     => /(\d{2}):(\d{2})/,
      :hnn_dots        => /(\d{1,2})\.(\d{2})/,
      :hnn_spaces      => /(\d{1,2})\s(\d{2})/,
      :hnn_dashes      => /(\d{1,2})-(\d{2})/,        
      :hnn_ampm_colons => [ /(\d{1,2}):(\d{2})\s?((?:a|p)\.?m\.?)/i,  lambda {|h, n, md| [full_hour(h, md), n, 0] } ],
      :hnn_ampm_dots   => [ /(\d{1,2})\.(\d{2})\s?((?:a|p)\.?m\.?)/i, lambda {|h, n, md| [full_hour(h, md), n, 0] } ],
      :hnn_ampm_spaces => [ /(\d{1,2})\s(\d{2})\s?((?:a|p)\.?m\.?)/i, lambda {|h, n, md| [full_hour(h, md), n, 0] } ],
      :hnn_ampm_dashes => [ /(\d{1,2})-(\d{2})\s?((?:a|p)\.?m\.?)/i,  lambda {|h, n, md| [full_hour(h, md), n, 0] } ],
      :h_ampm          => [ /(\d{1,2})\s?((?:a|p)\.?m\.?)/i,          lambda {|h, md| [full_hour(h, md), 0, 0] } ]
    }
    
    # The proc object should return an array with 3 elements with values 
    # ordered like so year, month, day. The proc should have as many
    # arguments as groups in the regexp or you will get an error.
    self.valid_date_formats = {
      :yyyymmdd_slashes => /(\d{4})\/(\d{2})\/(\d{2})/,
      :yyyymmdd_dashes  => /(\d{4})-(\d{2})-(\d{2})/,
      :yyyymmdd_slashes => /(\d{4})\.(\d{2})\.(\d{2})/,
      :mdyyyy_slashes   => [ /(\d{1,2})\/(\d{1,2})\/(\d{4})/, lambda {|m, d, y| [y, m, d] } ],
      :dmyyyy_slashes   => [ /(\d{1,2})\/(\d{1,2})\/(\d{4})/, lambda {|d, m ,y| [y, m, d] } ],
      :dmyyyy_dashes    => [ /(\d{1,2})-(\d{1,2})-(\d{4})/,   lambda {|d, m ,y| [y, m, d] } ],
      :dmyyyy_dots      => [ /(\d{1,2})\.(\d{1,2})\.(\d{4})/, lambda {|d, m ,y| [y, m, d] } ],
      :mdyy_slashes     => [ /(\d{1,2})\/(\d{1,2})\/(\d{2})/, lambda {|m, d ,y| [unambiguous_year(y), m, d] } ],
      :dmyy_slashes     => [ /(\d{1,2})\/(\d{1,2})\/(\d{2})/, lambda {|d, m ,y| [unambiguous_year(y), m, d] } ],
      :dmyy_dashes      => [ /(\d{1,2})-(\d{1,2})-(\d{2})/,   lambda {|d, m ,y| [unambiguous_year(y), m, d] } ],
      :dmyy_dots        => [ /(\d{1,2})\.(\d{1,2})\.(\d{2})/, lambda {|d, m ,y| [unambiguous_year(y), m, d] } ],
      :d_mmm_yyyy       => [ /(\d{1,2}) (\w{3,9}) (\d{4})/,   lambda {|d, m ,y| [y, m, d] } ],
      :d_mmm_yy         => [ /(\d{1,2}) (\w{3,9}) (\d{2})/,   lambda {|d, m ,y| [unambiguous_year(y), m, d] } ]
    }
    
    self.valid_datetime_formats = {
      :yyyymmdd_dashes_hhnnss_colons => /#{valid_date_formats[:yyyymmdd_dashes]}\s#{valid_time_formats[:hhnnss_colons]}/,
      :yyyymmdd_dashes_hhnn_colons   => /#{valid_date_formats[:yyyymmdd_dashes]}\s#{valid_time_formats[:hhnn_colons]}/,
      :iso8601 => /#{valid_date_formats[:yyyymmdd_dashes]}T#{valid_time_formats[:hhnnss_colons]}(?:Z|[-+](\d{2}):(\d{2}))?/
    }
    
    module ClassMethods
      
      def full_hour(hour, meridian)
        hour = hour.to_i
        if meridian.delete('.').downcase == 'am'
          hour == 12 ? 0 : hour
        else
          hour == 12 ? hour : hour + 12
        end
      end
      
      def unambiguous_year(year, threshold=30)
        year = "#{year.to_i < threshold ? '20' : '19'}#{year}" if year.length == 2
        year.to_i
      end
      
      # loop through regexp and call proc on matches if available. Allow pre or 
      # post match strings if bounded is false. Lastly fills out time_array to
      # full 6 part datetime array.
      def extract_date_time_values(time_string, formats, bounded=true)
        time_array = nil
        formats.each do |name, (regexp, processor)|
          matches = regexp.match(time_string.strip)
          if !matches.nil? && (!bounded || (matches.pre_match == "" && matches.post_match == ""))
            time_array = matches[1..6] if processor.nil?
            time_array = processor.call(matches[1..6]) unless processor.nil?
            time_array = time_array.map {|i| i.to_i }
            time_array += [nil] * (6 - time_array.length)
            break
          end
        end
        return time_array
      end

      # Override this method to use any date parsing algorithm you like such as 
      # Chronic. Just return nil for an invalid value and a Time object for a 
      # valid parsed value. 
      # 
      # Remember Rails, since version 2, will automatically handle the fallback
      # to a DateTime when you create a time which is out of range.      
      def timeliness_date_time_parse(raw_value, type, strict=true)
        return raw_value.to_time if raw_value.acts_like?(:time) || raw_value.is_a?(Date)
        
        time_array = extract_date_time_values(raw_value, self.send("valid_#{type}_formats".to_sym), strict)
        raise if time_array.nil?
        
        if type == :time          
          time_array[3..5] = time_array[0..2]
          # Rails dummy time date part is defined as 2000-01-01
          time_array[0..2] = 2000, 1, 1
        elsif type == :date
          # throw away time part and check date
          time_array[3..5] = 0, 0, 0
        end

        # Date.new enforces days per month, unlike Time
        Date.new(*time_array[0..2]) unless type == :time
        
        # Check time part, and return time object
        Time.local(*time_array)
      rescue
        nil
      end
      
      
      # The main validation method which can be used directly or called through
      # the other specific type validation methods.      
      def validates_timeliness_of(*attr_names)
        configuration = { :on => :save, :type => :datetime, :allow_nil => false, :allow_blank => false }
        configuration.update(timeliness_default_error_messages)
        configuration.update(attr_names.extract_options!)
        
        # we need to check raw value for blank or nil
        allow_nil   = configuration.delete(:allow_nil)
        allow_blank = configuration.delete(:allow_blank)
        
        validates_each(attr_names, configuration) do |record, attr_name, value|          
          raw_value = record.send("#{attr_name}_before_type_cast")

          next if (raw_value.nil? && allow_nil) || (raw_value.blank? && allow_blank)

          record.errors.add(attr_name, configuration[:blank_message]) and next if raw_value.blank?
          
          column = record.column_for_attribute(attr_name)
          begin
            unless time = timeliness_date_time_parse(raw_value, configuration[:type])
              record.send("#{attr_name}=", nil)
              record.errors.add(attr_name, configuration[:invalid_datetime_message] % configuration[:type])
              next
            end
           
            validate_timeliness_restrictions(record, attr_name, time, configuration)
          rescue Exception => e          
            record.send("#{attr_name}=", nil)
            record.errors.add(attr_name, configuration[:invalid_datetime_message] % configuration[:type])            
          end          
        end
      end   
      
      # Use this validation to force validation of values and restrictions 
      # as dummy time
      def validates_time(*attr_names)
        configuration = attr_names.extract_options!
        configuration[:type] = :time
        validates_timeliness_of(attr_names, configuration)
      end
      
      # Use this validation to force validation of values and restrictions 
      # as Date
      def validates_date(*attr_names)
        configuration = attr_names.extract_options!
        configuration[:type] = :date
        validates_timeliness_of(attr_names, configuration)
      end
      
      # Use this validation to force validation of values and restrictions
      # as Time/DateTime
      def validates_datetime(*attr_names)
        configuration = attr_names.extract_options!
        configuration[:type] = :datetime
        validates_timeliness_of(attr_names, configuration)
      end
      
     private
      
      # Validate value against the restrictions. Restriction values maybe of 
      # mixed type so evaluate them and convert them all to common type as
      # defined by type param.
      def validate_timeliness_restrictions(record, attr_name, value, configuration)
        restriction_methods = {:before => '<', :after => '>', :on_or_before => '<=', :on_or_after => '>='}
        
        conversion_method = case configuration[:type]
          when :time     then :to_dummy_time
          when :date     then :to_date
          when :datetime then :to_time
        end
                
        value = value.send(conversion_method)
        
        restriction_methods.each do |option, method|
          next unless restriction = configuration[option]
          begin
            compare = case restriction
              when Time, Date, DateTime
                restriction
              when Symbol
                record.send(restriction)
              when Proc
                restriction.call(record)
              else
                timeliness_date_time_parse(restriction, configuration[:type], false)
            end            
            
            next if compare.nil?
            
            compare = compare.send(conversion_method)
            record.errors.add(attr_name, configuration["#{option}_message".to_sym] % compare) unless value.send(method, compare)
          rescue
            record.errors.add(attr_name, "restriction '#{option}' value was invalid")
          end
        end
      end
      
      # Map error message keys to *_message to merge with validation options
      def timeliness_default_error_messages
        defaults = ActiveRecord::Errors.default_error_messages.slice(:blank, :invalid_datetime, :before, :on_or_before, :after, :on_or_after)
        returning({}) do |messages|
          defaults.each {|k, v| messages["#{k}_message".to_sym] = v }
        end
      end
                  
    end
  end
end
