require 'securerandom'
require File.join(File.dirname(__FILE__), "data_set", "label")

class DataSet
  include Enumerable

  attr_accessor :label

  attr_accessor :data
  attr_accessor :parent
  attr_reader :id

  def initialize(data: nil, label: nil, parent: nil, id: nil)
    self.data = data # We have to use `self` here because we have a custom setter for `data`
    @parent = parent
    @id = id || SecureRandom.uuid

    return unless label

    if label.is_a?(DataSet::Label)
      @label = label
    elsif label.is_a?(String)
      @label = DataSet::Label.new(label)
    elsif label.is_a?(Hash)
      @label = DataSet::Label.new(label.delete(:name), **label)
    else
      fail ArgumentError, 'Given unsupported label type to DataSet initialize'
    end
  end

  def <<(item)
    self.data ||= []
    fail(CannotAddToNonEnumerableData, parent: self, item: item) unless data_array?
    item.parent = self
    data.push(item)
  end
  alias_method :add_item, :<<

  def data=(items)
    items.each { |item| item.parent = self if item.is_a? DataSet } if items.is_a? Enumerable
    @data = items
  end

  def children
    return data if data_array?
    []
  end

  def siblings
    return [] if parent.nil?
    parent.children.reject { |c| c == self }
  end

  def oneling?
    siblings.none?
  end

  def compact_onelings
    filter(orphan_strategy: :adopt, keep_leafs: true) { |p, d| false if d.oneling? && !d.root? }
  end

  def root?
    parent.nil?
  end

  def empty?
    if data_array?
      data.all?(&:empty?)
    else
      data.respond_to?(:empty?) ? !!data.empty? : !data
    end
  end

  def branch?
    children.any?
  end

  def child_branches
    children.select(&:branch?)
  end

  def twig?
    !leaf? && children.all?(&:leaf?)
  end

  def leaf?
    children.none?
  end

  def leaf_labels
    return [] if leaf?
    return [] if children.none?
    return children.map(&:label) if twig?
    children.map(&:leaf_labels).flatten.uniq
  end

  def filter(leaf_label_id = nil, keep_leafs: false, orphan_strategy: :destroy, &block)
    fail ArgumentError, 'No block and no leaf_label_id passed' if !block_given? && leaf_label_id.nil?
    self.data.each_with_object(DataSet.new(id: id, label: label.deep_dup)) do |set, parent_set|
      if block_given?
        condition_met = yield(parent_set, set)
      else
        condition_met = set.leaf? ? (set.label.id == leaf_label_id) : nil
      end

      if condition_met == true
        parent_set.add_item(set.deep_dup)
      elsif condition_met.nil? && set.data_array?
        deep_filter_result = set.deep_dup.filter(leaf_label_id, keep_leafs: keep_leafs, orphan_strategy: orphan_strategy, &block)
        parent_set.add_item(deep_filter_result) if deep_filter_result.data
      elsif condition_met == false && set.data_array?
        if orphan_strategy == :adopt
          deep_filter_result = set.deep_dup.filter(leaf_label_id, keep_leafs: keep_leafs, orphan_strategy: orphan_strategy, &block)
          deep_filter_result.children.each { |c| parent_set.add_item(c) } if deep_filter_result.data
        end
      elsif condition_met.nil? && set.leaf?
        parent_set.add_item(set) if keep_leafs
      end

      parent_set
    end
  end

  def find(subtree_id)
    if id == subtree_id
      self
    elsif data_array?
      data.each do |child|
        match = child.find(subtree_id)
        return match if match
      end

      nil
    end
  end

  def <=>(other)
    return 0 if data == other.data && label == other.label
    return 1 if data && other.data.nil?
    return -1 if data.nil? && other.data
    return label.id <=> other.label.id if label.id <=> other.label.id
    return data <=> other.data if data.is_a?(Numeric) && other.data.is_a?(Numeric)
    data.size <=> other.data.size
  end

  # == is used for comparison of two instances directly
  def ==(other)
    other_data = other.data.nil? ? nil : (other.data.is_a?(Enumerable) ? other.data.sort : other.data )
    own_data = data.nil? ? nil : (data.is_a?(Enumerable) ? data.sort : data )
    other.label == label && other_data == own_data
  end

  # eql? and hash are both used for comparisons when you
  # call `.uniq` on an array of data sets.
  def eql?(other)
    self == other
  end

  def hash
    "#{data.hash}#{label.hash}".to_i
  end

  def deep_dup
    new_set = DataSet.new(id: id)
    new_set.label = DataSet::Label.new(dup_value(label.name), id: dup_value(label.id), meta: label.meta.marshal_dump) if label

    if data_array?
      new_set.data = children.map(&:deep_dup)
    else
      new_set.data = data
    end

    new_set
  end

  def value
    fail NotImplementedError, 'DataSet is not a leaf and thus has no value' unless leaf?
    data
  end

  def reduce
    yield reducable_values
  end

  def sum
    values = [reducable_values].flatten.compact
    return nil if values.empty?
    values.inject(&:+)
  end

  def average
    values = [reducable_values].flatten.compact
    return nil if values.empty?
    (values.inject(&:+).to_f / values.size).to_f
  end

  def reducable_values(set = nil)
    set ||= self
    return set.children.map { |c| reducable_values(c) } if set.data_array?
    set.data
  end

  def combine(other_data_set, operator)
    combined_data_set = dup
    if data_array? && other_data_set.data_array?
      combined_data_set.data = combine_data_array(other_data_set.children, operator)
    elsif !data_array? && !other_data_set.data_array?
      combined_data_set.data = combine_data_value(other_data_set.value, operator)
    else
      fail ArgumentError, "Can't combine array DataSet with value DataSet"
    end
    combined_data_set
  end

  def data_array?
    data.is_a? Array
  end

  def pretty_inspect(level = 0, final_s: '')
    prefix = ''

    if root?
      prefix << '* '
    else
      prefix << (' ' * (level) * 3) + '|- '
    end

    if label
      node_s = "#{prefix}#{label.name}"
    else
      node_s = "#{prefix} (no label)"
    end
    node_s += ": #{value}" if leaf?
    final_s += "#{node_s} \n"

    return final_s if children.none?

    children.each { |c| final_s << c.pretty_inspect(level + 1) }
    final_s
  end

  def each(&block)
    yield self
    children.each { |member| member.each(&block) } if data_array?
    self
  end

  private

  def dup_value(value)
    value.is_a?(Numeric) ? value : value.dup
  end

  def combine_data_array(other_children, operator)
    other_children = other_children.dup
    result = children.map do |child|
      other_child = other_children.find { |ods| ods.label == child.label }
      if other_child
        other_children.delete(other_child)
        child.combine(other_child, operator)
      else
        child
      end
    end
    result += other_children # The remaining other children (without matching child in this data set)
    result
  end

  def combine_data_value(other_value, operator)
    own_value = value

    # Always return nil if both values are nil (prevents summed data sets of being wrongly considered unempty and thus not hidden)
    return nil if own_value.nil? && other_value.nil?

    case operator.to_sym
    when :+, :-
      # When adding or subtracting treat nil (unknown) values as zero, instead of returning nil as summation result
      own_value ||= 0.0
      other_value ||= 0.0
    when :/
      # Prevent division by zero resulting in NaN/Infinity values
      other_value = nil if other_value&.zero?
    end

    return nil if own_value.nil? || other_value.nil?
    own_value.send(operator, other_value)
  end
end

class CannotAddToNonEnumerableData < StandardError
  def initialize(data = nil)
    @data = data
  end
end