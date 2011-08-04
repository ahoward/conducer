# TODO
#

module Conducer
  class Key < ::String

    def key_for(*keys)
      key = keys.flatten.join('.').strip
      key.split(%r/\s*[,.:_-]\s*/).map{|key| key =~ %r/^\d+$/ ? Integer(key) : key}
    end

  end
end
