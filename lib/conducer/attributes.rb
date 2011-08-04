class Attributes < ::Map
  Attributes.dot_keys! if Attributes.respond_to?(:dot_keys!)

  attr_accessor :conducer

  def initialize(*args, &block)
    conducers, args = args.partition{|arg| arg.is_a?(Conducer::Base)}
    @conducer = conducers.shift
    super(*args, &block)
  end
end
