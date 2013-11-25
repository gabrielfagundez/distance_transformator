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
    
    # Creamos el archivo de logs
    dis_log ||= Logger.new("#{Rails.root}/log/distances_log.txt")

    # Contador de iteraciones
    contador = 1

    dis_log.info 'Iniciando proceso en segundo plano..'
    dis_log.info 'Borrando archivo de resultados previo..'
    # Borramos ejecucion previa del algoritmo si existe
    begin
      FileUtils.rm(DISTANCES_FILE)
    rescue
    end

    # Leemos el archivo linea a linea
    File.open(LOCATIONS_FILE, 'r').each_line do |line|

      sanitized_line = line.split("\n")[0]

      # Imprimimos un asterisco por linea en la consola
      dis_log.info "Linea #{contador} procesada.."

      # Obtenemos los parametros
      parametros = "origins=#{ sanitized_line }&destinations=#{ DISTANCES.join('|') }"

      unless DISTANCES.empty?

        # Realizamos la consulta
        http_response = RestClient.get BASE_URI + PATH_URI + parametros + END_URI

        dis_log.info http_response.body.to_s
      end

      # Guardamos la linea
      DISTANCES.push(sanitized_line)

      # Actualizamos el contador
      contador = contador + 1

    end

    # Imprimimos el final
    dis_log.info 'Se ha finalizado el proceso en segundo plano..'

  end

end