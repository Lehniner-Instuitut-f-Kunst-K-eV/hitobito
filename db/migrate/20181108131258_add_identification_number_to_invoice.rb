class AddIdentificationNumberToInvoice < ActiveRecord::Migration
  def change
    add_column :invoice_configs, :identification_number, :integer
    add_column :invoices, :identification_number, :integer
  end
end
