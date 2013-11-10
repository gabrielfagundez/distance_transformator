class DistanceWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  BASE_URL = 'http://maps.googleapis.com/maps/api/distancematrix/json?mode=driving&language=es&sensor=false'

  # Este es el archivo de entrada
  LOCATIONS_FILE = ''

  # Este es el archivo de salida
  DISTANCES_FILE = ''


  # TODO: Procesamiento en segundo plano
  def perform

    puts 'Iniciando proceso en segundo plano..'
    # Borramos ejecucion previa del algoritmo si existe
    begin
      FileUtils.rm(DISTANCES_FILE)
    rescue
    end

    # Leemos el archivo linea a linea
    File.open(DISTANCES_FILE, 'r').each_line do |line|

      # Imprimimos un asterisco por linea
      print '*'

      ubicacion = line.split(',')
      latitud   = ubicacion[0]
      longitud  = ubicacion[1]


    end


  end

end