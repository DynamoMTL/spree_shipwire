module SpreeShipwire::StockEstimatorDecorator
  def shipping_rates(package)
    if @order.complete?
      super
    else
      refresh_shipping_rates(package)
    end
  end

private

  def refresh_shipping_rates(package)
    items = map_contents(package)
    quotes = SpreeShipwire::Rates.compute(@order.ship_address, items)

    rates = quotes.map do |quote|
      Spree::ShippingRate.new(
        carrier_code: quote[:carrier_code],
        name: quote[:service],
        cost: quote[:cost]
      )
    end

    choose_default_shipping_rate(rates)
    sort_shipping_rates(rates)
  end

  def map_contents(package)
    package.contents.reduce({}) do |acc, item|
      if acc[item.variant]
        acc[item.variant] += 1
      else
        acc[item.variant] = 1
      end

      acc
    end
  end
end

Spree::Stock::Estimator.prepend(SpreeShipwire::StockEstimatorDecorator)