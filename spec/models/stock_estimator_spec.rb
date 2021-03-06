require 'spec_helper'

describe Spree::Stock::Estimator do
  context "complete order" do
    it "uses existing rates" do
      order = create(:completed_order_with_totals)
      estimator = Spree::Stock::Estimator.new(order)

      shipment = order.shipments.first
      package = shipment.to_package

      expect(SpreeShipwire::Rates).to_not receive(:compute)

      rates = estimator.shipping_rates(package)

      expect(rates.count).to eq(1)
    end
  end

  context "incomplete order" do
    let!(:order) { create(:order_with_line_items) }
    let(:estimator) { Spree::Stock::Estimator.new(order) }
    let(:package) { order.shipments.first.to_package }

    it "gets rates" do
      computed_rates = [
        {
          code: 'FDX2',
          carrier_code: 'FDX2-A',
          service: 'FedEx CrazyFast',
          cost: 20.99,
          delivery_estimate: {minimum: "1", maximum: "1"}
        },
        {
          code: 'FDX1',
          carrier_code: 'FDX1-B',
          service: 'FedEx SuperFast',
          cost: 10.99,
          delivery_estimate: {minimum: "3", maximum: "5"}
        }
      ]

      expect(SpreeShipwire::Rates).to receive(:compute)
                                        .with(order.ship_address, {order.line_items.first.variant => 1})
                                        .and_return(computed_rates)

      rates = estimator.shipping_rates(package)

      expect(rates.count).to eq(2)

      rate = rates[0]
      expect(rate.code).to eq('FDX1')
      expect(rate.carrier_code).to eq('FDX1-B')
      expect(rate.name).to eq('FedEx SuperFast (3-5 days)')
      expect(rate.cost).to eq(10.99)
      expect(rate.selected).to eq(true)
      expect(rate.shipping_method).to_not be_nil
      expect(rate.shipping_method.name).to eq('FedEx SuperFast')

      rate = rates[1]
      expect(rate.code).to eq('FDX2')
      expect(rate.carrier_code).to eq('FDX2-A')
      expect(rate.name).to eq('FedEx CrazyFast (1 day)')
      expect(rate.cost).to eq(20.99)
      expect(rate.selected).to eq(false)
      expect(rate.shipping_method).to_not be_nil
      expect(rate.shipping_method.name).to eq('FedEx CrazyFast')
    end

    it "catches address errors" do
      expect(SpreeShipwire::Rates).to receive(:compute)
                                        .and_raise(SpreeShipwire::AddressError.new('Invalid address'))

      estimator.shipping_rates(package)

      expect(order.ship_address.remote_validation_error).to eq('Invalid address')
    end
  end
end
