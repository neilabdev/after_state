# frozen_string_literal: true
require "active_support/concern"

module AfterState
  # This callback helper safely calls a method when the state of a specified attribute has change
  #   allow for the update of affected models. usage:
  #     after_state :callback_method_name, field: :optional_column_name_to_monitor
  #     after_state :callback_method_name  # monitors :status by default
  #     after_state -> { }
  module Changed
    extend ActiveSupport::Concern

    included do
      after_commit :manage_state, on: [:create, :update, :destroy]
      class_attribute :after_state_settings
    end

    class_methods do
      # @param [Symbol|String] field  optional: Name of callback method to execute. OR provide block instead.
      # @param [Symbol|String] on  required: Name of attribute to track.
      # @param [Symbol|String] key    optional: If type is a store_accessor, specify the key to track.
      # @param [Object] value  optional: execute if value == changed_value
      # @param [Object] type   optional: execute only if changed value is of specific type
      # @param [Symbol|String] group  optional: Ensures callbacks with the same group only execute once.
      # @param [Proc||Symbol|String] if  optional: Executes callback only if condition is true.
      # @param [Proc] block optional: Block to execute if conditions match
      def after_state(field = nil, on: :status, key: nil, value: nil, type: nil, group: nil, if: nil, &block)
        code = field || block
        raise ArgumentError, "A block or option :field must be specified" unless code.present?

        self.after_state_settings ||= {}.with_indifferent_access

        Array(on).each do |on_attribute|
          self.after_state_settings[on_attribute] ||= []
          self.after_state_settings[on_attribute].push(OpenStruct.new(code:, group:, if:, types: Array.wrap(type), key:, values: Array.wrap(value)))
        end
      end
    end

    def perform_state_changes(*changed_fields)
      field_names = changed_fields.flatten.collect { |name| name.to_s }
      groups = {}
      self.class.after_state_settings&.each_pair do |field_name, field_settings|
        next unless changed_fields.blank? || field_names.include?(field_name)

        field_settings.each do |setting|
          last_change = if setting.key.present?
                          changed_store_accessor_value(field: field_name, key: setting.key)[1]
                        else
                          previous_changes[field_name]&.last
                        end

          next if setting.key.present? && !store_accessor_value_changed?(field: field_name, key: setting.key) #

          next if setting.values.present? && # Next only IF expecting to match value AND
            !setting.values.include?(last_change) # the value doesn't match.

          next if setting.types.present? && # Next only IF expecting to be a subclass of types, but isn't
            (setting.types.select { |t| last_change.is_a?(t.is_a?(Class) ? t : t.class) }).blank?

          if setting.group.present?
            # This insures that different callbacks that share the same group only execute once.
            next if groups[setting.group]

            groups[setting.group] = true
          end

          if setting.if
            resume = setting.if.is_a?(Proc) ? setting.if.call(self) : self.send(settings.if)

            next unless resume
          end

          if setting.code.is_a?(Proc)
            setting.code.call
          else
            self.send(setting.code)
          end
        end
      end

      nil
    end

    private

    def store_accessor_value_changed?(...) = changed_store_accessor_value(...).last

    # Return the updated value from a store_accessor hash.
    def changed_store_accessor_value(field:, key:)
      initial_store = previous_changes[field]&.first
      updated_store = previous_changes[field]&.last
      initial_value = initial_store&.try(:dig, key)
      updated_value = updated_store&.try(:dig, key)

      [initial_value, updated_value, initial_value != updated_value]
    end

    def manage_state
      unless previous_changes.keys.find { |k| self.class.after_state_settings&.keys&.include?(k) }
        return # return if state attribute not changed
      end

      ActiveRecord::Base.transaction do
        perform_state_changes(*previous_changes.keys)
      end
    rescue Exception => e
      Rails.logger.warn("Unable to perform state change for class: #{self.class.name} id: #{self.id} because: #{e.messages}")

      raise e
    end
  end
end

