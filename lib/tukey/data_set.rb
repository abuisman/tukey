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

  def ancestors
    return [] if parent.nil?
    ancs = []
    par = parent
    require 'pry'
    until par.nil?
      puts par.label.name
      ancs.push par
      par = par.parent
    end
    ancs.reverse
  end

  def label_path
    [ancestors, self].flatten.map(&:label)
  end

  def oneling?
    siblings.none?
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

  # Filter method that returns a new (dup) data_set with certain nodes filtered out
  # Filtering is done through either passing:
  #   1. a 'leaf_label_id'. All matching nodes will be present in the new set
  #   in their original position in the tree.
  #
  #   2. by passing a block that returns either `true`, `nil` or `false` for a given node:
  #         true: A node is kept, _including its children_
  #         nil: The matcher is indifferent about the node and will continue recursing the tree
  #               a. When at some point `true` is returned for a descendant node the whole branch will be
  #                 kept up to and including the node for which the block returned `true`.
  #               b. If `true` is not returned the whole branch will not be included in the filter result,
  #                 unless the option `keep_leafs` was set to true, in which case only nodes that were cut
  #                 off with `false` will be excluded in the result.
  #         false: When the block returns false for a given node that node is taken out of the results
  #                this inludes its children, unless the option `orphan_strategy` was set to `:adopt` in
  #                which case the children will be filtered using the same block and appended to first ancestor
  #                node that was not excluded by the filter.
  #
  def filter(leaf_label_id = nil, keep_leafs: false, orphan_strategy: :destroy, &block)
    fail ArgumentError, 'No block and no leaf_label_id passed' if !block_given? && leaf_label_id.nil?
    fail 'Cannot filter value DataSets' unless data_array?
    return self.dup if self.data.empty?

    self.data.each_with_object(DataSet.new(id: id, label: label.deep_dup)) do |set, parent_set|
      if block_given?
        condition_met = yield(parent_set, set)
      else
        condition_met = set.leaf? ? (set.label.id == leaf_label_id) : nil
      end

      set_dup = set.deep_dup

      # We want to have this node and its children
      if condition_met == true
        parent_set.add_item(set_dup)
      # Complex looking clause, but useful for performance and DRY-ness
      elsif set.data_array? && (condition_met.nil? || (condition_met == false && orphan_strategy == :adopt))
        deep_filter_result = set_dup.filter(leaf_label_id, keep_leafs: keep_leafs, orphan_strategy: orphan_strategy, &block)

        # Here is where either the taking along or adopting of nodes happens
        if deep_filter_result.data
          # Filtering underlying children and adding the potential filter result to parent.
          parent_set.add_item(deep_filter_result) if condition_met.nil?

          # We are losing the node, but since 'orphan_strategy' == :adopt we will adopt the orphans that match the filter
          deep_filter_result.children.each { |c| parent_set.add_item(c) } if condition_met == false
        end
      # We are indifferent to the match (nil), but since the node is a leaf we will keep it
      elsif condition_met.nil? && set.leaf?
        parent_set.add_item(set_dup) if keep_leafs
      end
    end
  end

  def find(subtree_id = nil, &block)
    return super if block_given?
    return self if id == subtree_id
    return nil unless data_array?
    data.each do |child|
      match = child.find(subtree_id)
      return match if match
    end
    nil
  end

  def find_by(query)
    return find { |s| s.to_comparable_h.deep_merge(query) == s.to_comparable_h }
  end

  def to_comparable_h
    ch = {
      id: self.id,
    }

    ch[:data] = data unless data_array?

    if label
      ch[:label] = {
        id: label.id,
        name: label.name,
        meta: label.meta.to_h,
      }
    end

    ch
  end

  def <=>(other)
    return 0 if data == other.data && label == other.label
    return 1 if data && other.data.nil?
    return -1 if data.nil? && other.data
    return label.id <=> other.label.id if label && other.label && label.id <=> other.label.id
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

  def transform_labels!(&block)
    self.label = yield(label)
    data.each { |d| d.transform_labels!(&block) } if data_array?
    self
  end

  def transform_values!(&block)
    if data_array?
      self.data = data.map { |d| d.transform_values!(&block) }
    else
      self.data = yield(value)
    end
    self
  end

  def merge(other_data_set, &block)
    merged_data_set = dup
    if data_array? && other_data_set.data_array? # Merge sets
      other_children = other_data_set.children.dup
      merged_children = children.map do |child|
        other_child = other_children.find { |ods| ods.label == child.label }
        if other_child
          other_children.delete(other_child)
          child.merge(other_child, &block)
        else
          child
        end
      end
      merged_children += other_children # The remaining other children (without matching child in this data set)
      merged_data_set.data = merged_children
    elsif !data_array? && !other_data_set.data_array? # Merge values
      if block_given? # Combine data using block
        merged_data_set.data = yield(label, value, other_data_set.value)
      else # Simply overwrite data with other data
        merged_data_set.data = other_data_set.value
      end
    else
      fail ArgumentError, "Can't merge array DataSet with value DataSet"
    end
    merged_data_set
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
end

class CannotAddToNonEnumerableData < StandardError
  def initialize(data = nil)
    @data = data
  end
end
