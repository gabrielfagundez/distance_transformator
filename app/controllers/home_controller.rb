class HomeController < ApplicationController

  def index

    # Calculamos las distancias en background
    DistanceWorker.perform_async

    render json: { outcome: 'PASS', message: 'Calculando las distancias en segundo plano, por favor, espere a que todo esté listo.' }
  end

end