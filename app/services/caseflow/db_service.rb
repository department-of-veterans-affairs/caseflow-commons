# frozen_string_literal: true

# Our external dependencies are slow and unreliable. If an external dependency takes a long
# time to respond we end up holding on to DB connections for an unreasonable amount of time.
# This enables us to release connections before making an external call.
module Caseflow
  class DBService
    def self.release_db_connections
      if FeatureToggle.enabled?(:release_db_connections)
        caseflow_vacols_record = "VACOLS::Record".constantize
        if caseflow_vacols_record.connection_pool.active_connection?
          Rails.logger.info("Releasing VACOLS DB Connection")
          caseflow_vacols_record.connection_pool.release_connection if caseflow_vacols_record.connection.open_transactions == 0
        end
        if ActiveRecord::Base.connection_pool.active_connection?
          Rails.logger.info("Releasing PG DB Connection")
          ActiveRecord::Base.connection_pool.release_connection if ActiveRecord::Base.connection.open_transactions == 0
        end
      end
    end
  end
end
