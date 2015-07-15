class DateCalculator
  attr_accessor :date

  def initialize(date, days)
    @date = days.business_days.before(date)
  end

  def calculate!
    Time.zone = 'Eastern Time (US & Canada)'
    today_date = Time.zone.now.hour > 14 ? Date.tomorrow : Date.today
    symbol = today_date > date ? :+ : :-
    until today_date < date && date.monday? || date.thursday? do
      self.date = date.send(symbol, 1.day)
    end
    date
  end
end
