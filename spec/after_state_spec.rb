# frozen_string_literal: true
require "spec_helper"

# 1. Simulate the gem module's functionality
module Post
  extend ActiveSupport::Concern

  included do
    include AfterState::Changed

    validates :text, presence: true
    validates :status, presence: true

    after_save_state :publish_content, on: :status, value: %w[published]
    after_save_state :cancel_content, on: :status, value: %w[canceled]
  end

  class_methods do
    # Define the model_name to avoid the ArgumentError
    def  model_name
      ActiveModel::Name.new(self, nil, "DynamicModel")
    end
  end
end

RSpec.describe AfterState do
  let(:example_model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations
      # include ActiveModel::Callbacks
      extend ActiveModel::Callbacks


      # Define the save callbacks
      define_model_callbacks :save, :create, :update, :destroy

      def save
        # Run the before_save and after_save blocks around your logic
        run_callbacks :save do
          # Your persistence/save logic goes here
          puts "Executing save logic..."
          true # return true to complete
        end
      end

      include Post

      # after_commit_state :notify_cashout_processing, on: :status, value: "processing"

      attr_accessor :status
      attr_accessor :text

      def publish_content
        puts "published"
      end

      def initialize(attributes = {})
        attributes.each do |name, value|
          send("#{name}=", value)
        end
      end
    end
  end

  subject { example_model_class.new }

  describe "after_save_state" do
    it "executes publish_content callback" do
      expect(subject).to receive(:publish_content).and_call_original

      subject.text = "hello"
      subject.status = "published"

      subject.save!
      #expect(subject).not_to be_valid
      ##expect(subject.errors[:text]).to include("can't be blank")
    end
  end
end
