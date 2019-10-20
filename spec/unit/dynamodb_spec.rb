require_relative './spec_helper'
require_relative './shared_examples'
require 'locksy/dynamodb'

describe Locksy::DynamoDB do
  def create_aws_client
    # run against a local docker dynamodb instance
    @client ||= Locksy::DynamoDB.create_client(endpoint: 'http://localhost:8000')
    # run against real dynamodb, using environment credentials
    # @client ||= Locksy::DynamoDB.create_client
  end

  def generate_instance(args)
    Locksy::DynamoDB.new(**args).tap { |ins| ins._clock = clock }
  end

  subject(:instance) { generate_instance init_args.merge(owner: 'owner1') }
  let(:other_owner) { generate_instance init_args.merge(owner: 'owner2') }
  let(:other_named_lock) { generate_instance init_args.merge(lock_name: 'other_lock') }
  let(:init_args) \
    { { table_name: 'test-lock-table', dynamo_client: dynamo_client, lock_name: lock_name } }
  let(:dynamo_client) { create_aws_client }
  let(:clock) { double('clock').tap { |clk| allow(clk).to receive(:now).and_return(*times) } }
  let(:times) { [30] }
  let(:lock_name) { 'my-test-lock-name' }

  before(:all) do
    client = create_aws_client
    begin
      client.delete_table(table_name: 'test-lock-table')
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException
      true # the table doesn't exist; no need to delete
    end
    Locksy::DynamoDB.new(table_name: 'test-lock-table', dynamo_client: client).create_table
    sleep 1
  end

  after do
    instance.force_unlock!
    other_owner.force_unlock!
    other_named_lock.force_unlock!
  end

  it_behaves_like 'a lock'
end
