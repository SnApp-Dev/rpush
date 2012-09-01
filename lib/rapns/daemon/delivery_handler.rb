module Rapns
  module Daemon
    class DeliveryHandler
      include DatabaseReconnectable

      attr_accessor :queue

      def deliver(notification)
        raise NotImplementedError
      end

      def start
        @thread = Thread.new do
          loop do
            break if @stop
            handle_next_notification
          end
        end
      end

      def stop
        @stop = true
        if @thread
          queue.wakeup(@thread)
          @thread.join
        end
        stopped
      end

      def stopped
      end

      protected

      def handle_next_notification
        begin
          notification = queue.pop
        rescue DeliveryQueue::WakeupError
          return
        end

        begin
          deliver(notification)
        rescue StandardError => e
          Rapns::Daemon.logger.error(e)
        ensure
          queue.notification_processed
        end
      end

      def mark_notification_delivered(notification)
        with_database_reconnect_and_retry do
          notification.delivered = true
          notification.delivered_at = Time.now
          notification.save!(:validate => false)
        end
      end

      def handle_delivery_error(notification, code, description)
        with_database_reconnect_and_retry do
          notification.delivered = false
          notification.delivered_at = nil
          notification.failed = true
          notification.failed_at = Time.now
          notification.error_code = code
          notification.error_description = description
          notification.save!(:validate => false)
        end
      end
    end
  end
end