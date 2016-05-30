module ApplicationHelper
  def percent(count, max)
    count > 0 ? (max <= 1 ? count : ((Math.log(count+1) * 100.0) / Math.log(max+1)).to_i) : -1
  end
end
