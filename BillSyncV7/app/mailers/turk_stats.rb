class TurkStats < ActionMailer::Base

  def stats(stats, emails)
    @stats = stats

    mail(
      to:       emails,
      from:     "BillSync API <developers@bill-sync.com>",
      subject:  "BillSync stats"
    )
  end

end
