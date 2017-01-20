require 'ostruct'

class DataSet
  class Label
    attr_accessor :id
    attr_accessor :name
    attr_accessor :meta

    def initialize(name, id: nil, meta: {})
      @name = name
      @id = id || name
      fail ArgumentError, 'DataSet::Label meta must be a Hash' unless meta.is_a?(Hash)
      @meta = OpenStruct.new(meta)
    end

    # == is used for comparison of two instances directly
    def ==(other)
      other.id == id
    end

    # eql? and hash are both used for comparisons when you
    # call `.uniq` on an array of labels.
    def eql?(other)
      self == other
    end

    def hash
      id.hash
    end

    def deep_dup
      label = dup
      id = id.dup if id
      name = name.dup if name
      meta = meta.dup if meta
      label
    end
  end
end
