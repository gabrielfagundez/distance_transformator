class DistanceWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  BASE_URI  = 'http://maps.googleapis.com/maps/api/distancematrix/json'
  PATH_URI  = '?'
  END_URI   = '&mode=driving&language=es&sensor=false'

  # Este es el archivo de entrada
  LOCATIONS_FILE = 'entrada.txt'

  # Este es el archivo de salida
  DISTANCES_FILE  = 'salida.txt'
  NAMES_FILE      = 'names.txt'

  # Distancias
  DISTANCES = []
  NAMES     = []

  def perform
    
    # Creamos el archivo de logs
    @dis_log ||= Logger.new("#{Rails.root}/log/distances_log.txt")

    # Contador de iteraciones
    contador = 1

    @dis_log.info 'Iniciando proceso en segundo plano..'
    @dis_log.info 'Borrando archivo de resultados previo..'
    # Borramos ejecucion previa del algoritmo si existe
    begin
      FileUtils.rm(DISTANCES_FILE)
    rescue
    end

    begin
      FileUtils.rm(NAMES_FILE)
    rescue
    end

    # Leemos el archivo linea a linea
    File.open(LOCATIONS_FILE, 'r').each_line do |line|

      sanitized_line = line.split("\n")[0]
      @dis_log.info "Procesando linea #{contador}.."

      # Obtenemos los parametros
      parametros = "origins=#{ sanitized_line }&destinations=#{ DISTANCES.join('|') }"

      unless DISTANCES.empty?

        # Realizamos la consulta
        http_response = HTTParty.get(BASE_URI + PATH_URI + parametros + END_URI)
        json_response = JSON[http_response.body]

        if json_response['status'] == 'OK'

          # Obtenemos el nombre y lo almacenamos
          NAMES.push(json_response['origin_addresses'][0])

          # Obtenemos la distancia y la almacenamos
          distances = []
          json_response['rows'][0]['elements'].each do |destination|
            if destination['status'] == 'OK'
              distances.push(destination['distance']['value'])
            else
              @dis_log.info 'Ha ocurrido un error en la consulta puntual. El resultado es el siguiente: '
              @dis_log.info destination.to_hash.inspect
              @dis_log.info 'Para mas informacion: https://developers.google.com/maps/documentation/distancematrix/'
              @dis_log.info 'Las causas pueden ser: NOT_FOUND > La posicion no se puede localizar. ZERO_RESULTS No existe una ruta entre origen y destino.'
              return
            end
          end
          DISTANCES.push(distances)

        else
          @dis_log.info 'Ha ocurrido un error en la consulta:'
          @dis_log.info json_response.inspect
          @dis_log.info 'Para mas informacion: https://developers.google.com/maps/documentation/distancematrix/'
          @dis_log.info 'Las causas pueden ser: '
          @dis_log.info 'INVALID_REQUEST > Consulta erronea.'
          @dis_log.info 'MAX_ELEMENTS_EXCEEDED > Se excede el maximo por consulta.'
          @dis_log.info 'OVER_QUERY_LIMIT > Se han recibido muchas consultas desde esta IP en un corto periodo de tiempo.'
          @dis_log.info 'REQUEST_DENIED > Se prohibe el acceso de este sitio.'
          return
        end

      else
        DISTANCES.push([])
      end

      # Guardamos la linea
      DISTANCES.push(sanitized_line)

      # Actualizamos el contador
      contador = contador + 1

      @dis_log.info "Linea #{contador} procesada.."

    end

    # Imprimimos el final
    @dis_log.info 'El arreglo de distancias tiene el siguiente aspecto:'
    @dis_log.info DISTANCES.inspect

    @dis_log.info 'Los nombre calculados tienen el siguiente aspecto:'
    @dis_log.info NAMES.inspect

    @dis_log.info 'Se ha finalizado el proceso en segundo plano..'

  end

end
