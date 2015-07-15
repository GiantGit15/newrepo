module AnchorsHelper

  def invoice_anchor invoice
    "/invoice/#{invoice.to_param}/edit/"
  end

end
