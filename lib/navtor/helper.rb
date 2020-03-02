# typed: false
class Object
  def then
    return to_enum(__method__) { 1 } unless block_given?
    yield self
  end unless method_defined? :then
end

