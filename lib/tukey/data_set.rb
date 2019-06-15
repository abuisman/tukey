# frozen_string_literal: true

require 'securerandom'
require File.join(File.dirname(__FILE__), 'data_set', 'label')

class DataSet
  include Enumerable

  attr_accessor :label

  attr_reader :data
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
      raise ArgumentError, 'Given unsupported label type to DataSet initialize'
    end
  end

  def <<(item)
    self.data ||= []
    raise(CannotAddToNonEnumerableData, parent: self, item: item) unless data_array?

    item.parent = self
    data.push(item)
  end
  alias add_item <<

  def data=(items)
    items.each { |item| item.parent = self if item.is_a? DataSet } if items.is_a? Enumerable
    @data = items
  end

  def children
    return data if data_array?

    []
  end

  def leafs
    children.select(&:leaf?)
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
    leaf? ? siblings.none? : siblings.reject(&:leaf?).none?
  end

  def root?
    parent.nil?
  end

  def empty?
    if data_array?
      data.all?(&:empty?)
    else
      data.respond_to?(:empty?) ? data.empty? : !data
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
  #                which case the children will be filtered using the same block & appended to first ancestor
  #                node that was not excluded by the filter.
  #
  def filter(leaf_label_id = nil, keep_leafs: false, orphan_strategy: :destroy, &block)
    raise ArgumentError, 'No block and no leaf_label_id passed' if !block_given? && leaf_label_id.nil?

    unless data_array?
      if block_given?
        return dup if yield(dup, dup)
      elsif label.id == leaf_label_id
        return dup
      end

      return []
    end

    return dup if self.data.empty?

    new_data_set = DataSet.new(label: label.deep_dup, data: nil, parent: parent, id: id)
    self.data.each_with_object(new_data_set) do |set, parent_set|
      condition_met = if block_given?
        yield(parent_set, set)
      else
        set.leaf? ? (set.label.id == leaf_label_id) : nil
      end

      set_dup = set.deep_dup

      # We want to have this node and its children
      if condition_met == true
        parent_set.add_item(set_dup)
      # Complex looking clause, but useful for performance and DRY-ness
      elsif set.data_array? && (condition_met.nil? || (condition_met == false && orphan_strategy == :adopt))
        deep_filter_result = set_dup.filter(
          leaf_label_id,
          keep_leafs: keep_leafs,
          orphan_strategy: orphan_strategy,
          &block
        )

        # Here is where either the taking along or adopting of nodes happens
        if deep_filter_result.data && !deep_filter_result.data.empty?
          # Filtering underlying children and adding the potential filter result to parent.
          parent_set.add_item(deep_filter_result) if condition_met.nil?

          # We are losing the node, but since 'orphan_strategy' == :adopt we will adopt the orphans
          # that match the filter
          deep_filter_result.children.each { |c| parent_set.add_item(c) } if condition_met == false
        end
      # We are indifferent to the match (nil), but since the node is a leaf we will keep it
      elsif condition_met.nil? && set.leaf?
        parent_set.add_item(set_dup) if keep_leafs
      end
    end
  end

  def find(subtree_id = nil, &block)
    return super if block_given? # It recursively searches descendants for data set matching block
    return self if id == subtree_id
    return nil unless data_array?

    data.each do |child|
      match = child.find(subtree_id)
      return match if match
    end
    nil
  end

  def find_by(query)
    find { |s| s.to_comparable_h.deep_merge(query) == s.to_comparable_h }
  end

  def to_comparable_h
    { id: id }.tap do |ch|
      ch[:data] = data unless data_array?
      ch[:label] = { id: label.id, name: label.name, meta: label.meta.to_h } if label
    end
  end

  def <=>(other)
    return 0 if data == other.data && label == other.label
    return 1 if data && other.data.nil?
    return -1 if data.nil? && other.data
    return 1 if data_array? && !other.data_array?
    return -1 if !data_array? && other.data_array?
    return label.id <=> other.label.id if label && other.label && label.id <=> other.label.id
    return data.size <=> other.data.size if data_array? && other.data_array?

    data <=> other.data
  end

  # == is used for comparison of two instances directly
  def ==(other)
    other_data = if other.data.nil?
      nil
    elsif other.data.is_a?(Enumerable)
      other.data.sort
    else
      other.data
    end

    own_data = if data.nil?
      nil
    elsif data.is_a?(Enumerable)
      data.sort
    else
      data
    end

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
    if label
      label_name = dup_value(label.name)
      label_id = dup_value(label.id)
      label_metadata = label.meta.marshal_dump
      new_set.label = DataSet::Label.new(label_name, id: label_id, meta: label_metadata)
    end
    new_set.data = if data_array?
      children.map(&:deep_dup)
    else
      data
    end

    new_set
  end

  def inspect
    data_display = data_array? ? "children: [#{children.map { |d| "#{d.label.name}..." }.join(', ')}]" : value
    "<DataSet:#{object_id} label=#{label.name} data: #{data_display}>"
  end

  def value
    raise NotImplementedError, 'DataSet is not a leaf and thus has no value' unless leaf?

    data
  end

  def reduce
    yield reducable_values
  end

  def sum
    # Leafs are considered a sum of their underlying data_sets,
    # therefore we can just sum the leafs if present.
    return value == [] ? nil : value if leaf? # TODO: Make redundant by not allowing [] in `data`

    values = (leafs.any? ? leafs.map(&:value) : children.map(&:sum)).compact
    return nil if values.empty?

    values.inject(&:+)
  end

  def child_sum(by_labels: nil, by_leaf_labels: false)
    raise 'choose either `by_leaf_labels` or `by_labels`' if by_leaf_labels == true && !by_labels.nil?

    by_labels = leaf_labels if by_leaf_labels

    children.map do |child|
      values = if by_labels.nil?
        child.sum
      else
        by_labels.map do |label|
          [label, child.filter(label.id)&.sum]
        end
      end

      [child, child.label, values]
    end
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
    self.label = yield(label, self)
    data.each { |d| d.transform_labels!(&block) } if data_array?
    self
  end

  def transform_values!(&block)
    self.data = if data_array?
      data.map { |d| d.transform_values!(&block) }
    else
      yield(value, self)
    end
    self
  end

  def merge(other_data_set, &block)
    dup.tap do |merged_data_set|
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
        # The remaining other children (without matching child in this data set)
        merged_children += other_children
        merged_data_set.data = merged_children
      elsif !data_array? && !other_data_set.data_array? # Merge values
        merged_data_set.data = if block_given? # Combine data using block
          yield(label, value, other_data_set.value)
        else # Simply overwrite data with other data
          other_data_set.value
        end
      elsif data.nil? || other_data_set.data.nil?
        self.data = [] if data.nil?
        other_data_set.data = [] if other_data_set.data.nil?
        return merge(other_data_set, &block)
      else
        raise ArgumentError, "Can't merge array DataSet with value DataSet"
      end
    end
  end

  def data_array?
    data.is_a? Array
  end

  def nice_inspect(level = 0, final_s: '')
    prefix = root? ? '* ' : (' ' * level * 3) + '|- '
    node_s = label ? "#{prefix}#{label.name}" : "#{prefix} (no label)"

    node_s += ": #{value}" if leaf?
    final_s += "#{node_s} \n"

    return final_s if children.none?

    children.each { |c| final_s << c.nice_inspect(level + 1) }
    final_s
  end

  def pretty_print
    puts nice_inspect
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
