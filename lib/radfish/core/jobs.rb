# frozen_string_literal: true

module Radfish
  module Core
    module Jobs
      def jobs
        raise NotImplementedError, "Adapter must implement #jobs"
      end
      
      def job_status(job_id)
        raise NotImplementedError, "Adapter must implement #job_status"
      end
      
      def wait_for_job(job_id, timeout: 600)
        raise NotImplementedError, "Adapter must implement #wait_for_job"
      end
      
      def cancel_job(job_id)
        raise NotImplementedError, "Adapter must implement #cancel_job"
      end
      
      def clear_completed_jobs
        raise NotImplementedError, "Adapter must implement #clear_completed_jobs"
      end
      
      def jobs_summary
        raise NotImplementedError, "Adapter must implement #jobs_summary"
      end
    end
  end
end