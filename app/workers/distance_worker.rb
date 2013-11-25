class DistanceWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  BASE_URI  = 'http://maps.googleapis.com/maps/api/distancematrix/json'
  PATH_URI  = '?'
  END_URI   = '&mode=driving&language=es&sensor=false'

  # Este es el archivo de entrada
  LOCATIONS_FILE = 'entrada.txt'

  # Este es el archivo de salida
  DISTANCES_FILE = 'salida.txt'

  # Distancias
  DISTANCES = []

  def perform

    Rails.logger.debug 'Iniciando proceso en segundo plano..'

    # Borramos ejecucion previa del algoritmo si existe
    begin
      FileUtils.rm(DISTANCES_FILE)
    rescue
    end

    # Leemos el archivo linea a linea
    File.open(LOCATIONS_FILE, 'r').each_line do |line|

      sanitized_line = line.split("\n")[0]

      # Imprimimos un asterisco por linea en la consola
      Rails.logger.debug '*'

      # Obtenemos los parametros
      parametros = "origins=#{ sanitized_line }&destinations=#{ DISTANCES.join('|') }"


      Rails.logger.debug '----------------------'
      Rails.logger.debug (BASE_URI + PATH_URI + parametros + END_URI)

      unless DISTANCES.empty?

        # Realizamos la consulta
        http_response = RestClient.get BASE_URI + PATH_URI + parametros + END_URI


        Rails.logger.debug http_response.body
        Rails.logger.debug '----------------------'
      end

      # Guardamos la linea
      DISTANCES.push(sanitized_line)

    end

    # Imprimimos el final
    Rails.logger.debug 'Se ha finalizado el proceso en segundo plano..'

  end

end