# frozen_string_literal: true
require "spec_helper"

# 1. Simulate the gem module's functionality
class Post < ActiveRecord::Base
  include AfterState::Changed

  validates :content, presence: true
  validates :status, presence: true

  after_save_state :publish_content, on: :status, value: %w[published]
  after_save_state :cancel_content, on: :status, value: %w[canceled]

  def publish_content
    puts "published"
  end

  def cancel_content
    puts "cancelled"
  end
end

RSpec.describe AfterState do
  subject { Post.new }

  describe "after_save_state" do
    it "executes publish_content callback" do
      expect(subject).to receive(:publish_content).and_call_original
      expect(subject).to_not receive(:cancel_content)

      subject.content = "hello"
      subject.status = "published"

      subject.save!

      expect(subject.after_state_changes).to be_present
    end

    it "executes published & cancel_content on transition" do
      expect(subject).to receive(:publish_content).and_call_original

      subject.update!(content: "hello", status: "published")

      expect(subject.after_state_changed(:status)).to eq "published"

      expect(subject).to receive(:cancel_content).and_call_original

      subject.update!(status: "canceled")

      expect(subject.after_state_changed(:status)).to eq "canceled"
    end
  end
end
