# frozen_string_literal: true

class AddCampaignIndexToDisbursements < ActiveRecord::Migration[8.1]
  def change
    add_index :disbursements, :campaign_id
  end
end
