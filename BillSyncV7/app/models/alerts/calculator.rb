class Alerts::Calculator
  attr_accessor :array

  def initialize(array = [])
    @array = array
  end

  def standard_deviation
    Math.sqrt(sample_variance(array))
  end

  def sum(a)
    a.inject(0){ |accum, i| accum + ( i || 0)}
  end

  def mean
    sum(array) / array.length.to_f
  end

  def sample_variance(a)
    sum = a.inject(0){ |accum, i| accum + (i - mean) ** 2 }
    sum / (a.length - 1).to_f
  end

  def count
    array.length
  end
end
