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
      after_save :manage_save_state
      after_commit :manage_commit_state, on: [:create, :update, :destroy]

      class_attribute :after_state_commit_settings
      class_attribute :after_state_save_settings
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
      def after_state(field = nil, event: :commit, on: :status, key: nil, value: nil, type: nil, group: nil, if: nil, &block)
        code = field || block
        raise ArgumentError, "A block or option :field must be specified" unless code.present?
        raise ArgumentError, ":event must be either :commit or :save" unless [:commit,:save].include?(event)

        self.after_state_commit_settings ||= {}.with_indifferent_access
        self.after_state_save_settings ||= {}.with_indifferent_access

        current_settings = event == :commit ? self.after_state_commit_settings : self.after_state_save_settings

        Array(on).each do |on_attribute|
          current_settings[on_attribute] ||= []
          current_settings[on_attribute].push(OpenStruct.new(code:, group:, if:, types: Array.wrap(type), key:, values: Array.wrap(value)))
        end
      end

      def after_save_state(field = nil, **opts) = after_state(field, **opts.merge(event: :save))
      def after_commit_state(field = nil, **opts) = after_state(field, **opts.merge(event: :commit))
    end

    # A cached version of :saved_changes which persist throughout all after_state callbacks in the chain
    #
    # @see https://github.com/rails/rails/issues/43645
    def after_state_changes(clear: false)
      @after_state_changes = nil if clear
      @after_state_changes ||= saved_changes
    end

    # Returns the value that field changed to
    def after_state_changed(field)
      after_state_changes[field]&.last
    end

    private

    def store_accessor_value_changed?(...) = changed_store_accessor_value(...).last

    # Return the updated value from a store_accessor hash.
    def changed_store_accessor_value(field:, key:)
      initial_store = after_state_changes[field]&.first
      updated_store = after_state_changes[field]&.last
      initial_value = initial_store&.try(:dig, key)
      updated_value = updated_store&.try(:dig, key)

      [initial_value, updated_value, initial_value != updated_value]
    end

    def manage_commit_state = manage_state(self.class.after_state_commit_settings, event: :commit)

    def manage_save_state
      # Clear changes from any previous save
      after_state_changes(clear: true)

      manage_state(self.class.after_state_save_settings, event: :save)
    end

    def manage_state(state_settings, event:)
      unless after_state_changes.keys.find { |k| state_settings&.keys&.include?(k) }
        return # return if state attribute not changed
      end

      ActiveRecord::Base.transaction do
        perform_state_changes(*after_state_changes.keys, state_settings: state_settings, event:)
      end
    rescue Exception => e
      Rails.logger.warn("Unable to perform state change for class: #{self.class.name} id: #{self.id} because: #{e.message}")

      raise e
    end

    # Handles processing each :after_state callback
    def perform_state_changes(*changed_fields, state_settings:, event:)
      field_names = changed_fields.flatten.collect { |name| name.to_s }
      groups = {}
      state_settings&.each_pair do |field_name, field_settings|
        next unless changed_fields.blank? || field_names.include?(field_name)

        field_settings.each do |setting|
          last_change = if setting.key.present?
                          changed_store_accessor_value(field: field_name, key: setting.key)[1]
                        else
                          after_state_changes[field_name]&.last
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
            self.__send__(setting.code)
          end
        end
      end

      nil
    end
  end
end

