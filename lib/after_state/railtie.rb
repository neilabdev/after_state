require 'rails/railtie'
require 'rails'

module Microcosm
  class Railtie < Rails::Railtie
    railtie_name :after_state

    rake_tasks { Dir[File.join(File.dirname(__FILE__), 'tasks/*.rake')].each { |f| load f } }
  end
end