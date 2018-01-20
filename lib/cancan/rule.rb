require_relative 'conditions_matcher.rb'
module CanCan
  # This class is used internally and should only be called through Ability.
  # it holds the information about a "can" call made on Ability and provides
  # helpful methods to determine permission checking and conditions hash generation.
  class Rule # :nodoc:
    include ConditionsMatcher
    attr_reader :base_behavior, :subjects, :actions, :conditions, :attributes
    attr_writer :expanded_actions

    # The first argument when initializing is the base_behavior which is a true/false
    # value. True for "can" and false for "cannot". The next two arguments are the action
    # and subject respectively (such as :read, @project). The third argument is a hash
    # of conditions and the last one is the block passed to the "can" call.
    def initialize(base_behavior, action, subject, *extra_args, &block)
      # for backwards compatibility, attributes are an optional parameter. Check if
      # attributes were passed or are actually conditions
      attributes, conditions = parse_attributes_from_conditions(extra_args)
      condition_and_block_check(conditions, block, action, subject)
      @match_all = action.nil? && subject.nil?
      @base_behavior = base_behavior
      @actions = Array(action)
      @subjects = Array(subject)
      @attributes = Array(attributes)
      @conditions = conditions || {}
      @block = block
    end

    # Matches the action, subject, and attribute; not necessarily the conditions
    def relevant?(action, subject, attribute = nil)
      subject = subject.values.first if subject.class == Hash
      @match_all || (matches_action?(action) && matches_subject?(subject) && matches_attribute?(attribute))
    end

    def only_block?
      conditions_empty? && @block
    end

    def only_raw_sql?
      @block.nil? && !conditions_empty? && !@conditions.is_a?(Hash)
    end

    def unmergeable?
      @conditions.respond_to?(:keys) && @conditions.present? &&
        (!@conditions.keys.first.is_a? Symbol)
    end

    def associations_hash(conditions = @conditions)
      hash = {}
      if conditions.is_a? Hash
        conditions.map do |name, value|
          hash[name] = associations_hash(value) if value.is_a? Hash
        end
      end
      hash
    end

    def attributes_from_conditions
      attributes = {}
      if @conditions.is_a? Hash
        @conditions.each do |key, value|
          attributes[key] = value unless [Array, Range, Hash].include? value.class
        end
      end
      attributes
    end

    private

    def matches_action?(action)
      @expanded_actions.include?(:manage) || @expanded_actions.include?(action)
    end

    def matches_subject?(subject)
      @subjects.include?(:all) || @subjects.include?(subject) || matches_subject_class?(subject)
    end

    def matches_attribute?(attribute)
      return true if @attributes.empty?
      return @base_behavior if attribute.nil?
      @attributes.include?(attribute.to_sym)
    end

    def matches_subject_class?(subject)
      @subjects.any? do |sub|
        sub.is_a?(Module) && (subject.is_a?(sub) ||
          subject.class.to_s == sub.to_s ||
          (subject.is_a?(Module) && subject.ancestors.include?(sub)))
      end
    end

    def parse_attributes_from_conditions(args)
      if args.first.is_a?(Symbol) || # use symbols to represent attributes
         (args.first.is_a?(Array) && args.first.first.is_a?(Symbol)) || # array of attributes
         args.first.nil? # nil is passed in because conditions needs to be one of the above

        attributes = args.shift
      end
      conditions = args.shift

      [attributes, conditions]
    end

    def condition_and_block_check(conditions, block, action, subject)
      return unless conditions.is_a?(Hash) && block
      raise BlockAndConditionsError, 'A hash of conditions is mutually exclusive with a block.'\
        "Check #{action} #{subject} ability."
    end
  end
end
