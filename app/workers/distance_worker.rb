class DistanceWorker
  include Sidekiq::Worker

  def perform
    # Do something..
  end

end