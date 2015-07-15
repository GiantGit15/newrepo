class Alerts::BaseAlertObserver

  def watch_for(*args)
    args.each do |arg|
      send(arg)
    end
  end

  protected

  def create_alert(category, model, average = nil)
    Alerts::AlertCreator.create({invoice_owner: invoice, category: category, alertable: model, average: average})
  end

  def calculator_for relation, column
    values = relation.pluck(column).compact
    Alerts::Calculator.new(values)
  end

  def reasonable_calculation? calculator
    calculator.count >= 10 && calculator.standard_deviation > 0.75 && !!calculator.mean
  end

end
