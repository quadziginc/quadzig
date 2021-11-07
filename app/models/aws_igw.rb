class AwsIgw < ApplicationRecord
  belongs_to :aws_account

  def default_label
    'IGW'
  end
end