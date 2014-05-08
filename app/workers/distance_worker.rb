class DistanceWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  BASE_URI  = 'http://maps.googleapis.com/maps/api/distancematrix/json'
  PATH_URI  = '?'
  END_URI   = '&mode=driving&language=es&sensor=false'

  TFF_ENTITY  = 'http://api.taxifarefinder.com/entity?key=d6apr3UDROuv&location='
  TFF_CALCULO = 'http://api.taxifarefinder.com/fare?key=d6apr3UDROuv&'

  # Este es el archivo de entrada
  ENTRADA_TXT = 'entrada.txt'

  # Este es el archivo de salida
  SALIDA_TXT  = 'costos.txt'
  SALIDA_TXT_DURACION  = 'duracion.txt'

  # Este es el archivo de bandera
  BANDERA_TXT  = 'bandera.txt'

  def perform
    
    # Creamos el archivo de logs
    @dis_log ||= Logger.new("#{Rails.root}/log/distances_log.txt")

    # Contador de iteraciones
    contador = 1

    @dis_log.info 'Iniciando proceso en segundo plano..'
    @dis_log.info 'Borrando archivo de resultados previo..'
    # Borramos ejecucion previa del algoritmo si existe
    begin
      FileUtils.rm(Rails.root + '/' + SALIDA_TXT)
    rescue
    end

    begin
      FileUtils.rm(Rails.root + '/' + BANDERA_TXT)
    rescue
    end

    @costos   = []
    @duracion = []
    @destinos = []
    @bandera  = nil
    @matriz_costos = nil

    # Leemos el archivo linea a linea
    File.open(ENTRADA_TXT, 'r').each_line do |line|

      sanitized_line = line.split("\n")[0]
      @dis_log.info "Procesando linea #{contador}.."

      calcular_costo(sanitized_line)

      # Actualizamos el contador
      contador = contador + 1

      @dis_log.info "Linea #{contador} procesada.."
    end

    armar_matriz_costos
    armar_matriz_duracion
    crear_archivo_de_bandera

    # Imprimimos el final
    @dis_log.info 'El arreglo de distancias tiene el siguiente aspecto:'
    @dis_log.info @destinos.inspect

    @dis_log.info 'El arreglo de costos tiene el siguiente aspecto:'
    @dis_log.info @costos.inspect

    @dis_log.info 'La matriz de costos tiene el siguiente aspecto:'
    @dis_log.info @matriz_costos.inspect

    @dis_log.info 'La bandera es:'
    @dis_log.info @bandera.inspect

    crear_archivo_de_costos

    @dis_log.info 'Se ha finalizado el proceso en segundo plano..'

    @dis_log.info '***********************************************'
    @dis_log.info '***********************************************'
    @dis_log.info '***********************************************'

  end

  def calcular_costo(string_origen)

    if @destinos.empty?

      # Realizamos la consulta
      url = TFF_ENTITY + string_origen

      @dis_log.info url

      http_response = HTTParty.get(url)
      json_response = JSON[http_response.body]

      @dis_log.info json_response.inspect

      @entity = json_response['handle']
      @destinos.push(string_origen)
      @costos.push([])
    else

      costos = []
      duracion = []

      @destinos.each do |destino|

        parametros = {
            entity_handle:  @entity,
            origin:         string_origen,
            destination:    destino
        }

        # Realizamos la consulta
        http_response = HTTParty.get(TFF_CALCULO + parametros.to_param)
        json_response = JSON[http_response.body]

        @dis_log.info json_response.inspect

        costos.push(json_response['metered_fare'])
        duracion.push(json_response['duration'])
        @bandera = json_response['initial_fare']
      end

      @costos.push(costos)
      @duracion.push(duracion)
      @destinos.push(string_origen)
    end
  end

  def armar_matriz_costos

    cantidad_marcadores = @costos.size

    @dis_log.info 'Calculando la matriz de costos..'
    @dis_log.info 'Se tienen en cuenta ' + cantidad_marcadores.to_s + ' marcadores.'

    # Matriz de costos
    @matriz_costos  = Array.new(cantidad_marcadores) { Array.new(cantidad_marcadores) }

    # Rellenamos la matriz de costos
    for i in 0..(cantidad_marcadores - 1) do
      for j in 0..(cantidad_marcadores - 1) do
        if i == j
          @matriz_costos[i][j] = 0
        else
          if i>j
            @matriz_costos[i][j] = @costos[i][j]
          else
            @matriz_costos[i][j] = @costos[j][i]
          end
        end
      end
    end
  end

  def armar_matriz_duracion

    cantidad_marcadores = @duracion.size

    @dis_log.info 'Calculando la matriz de duracion..'
    @dis_log.info 'Se tienen en cuenta ' + cantidad_marcadores.to_s + ' marcadores.'

    # Matriz de costos
    @matriz_duracion  = Array.new(cantidad_marcadores) { Array.new(cantidad_marcadores) }

    # Rellenamos la matriz de costos
    for i in 0..(cantidad_marcadores - 1) do
      for j in 0..(cantidad_marcadores - 1) do
        if i == j
          @matriz_duracion[i][j] = 0
        else
          if i>j
            @matriz_duracion[i][j] = @duracion[i][j]
          else
            @matriz_duracion[i][j] = @duracion[j][i]
          end
        end
      end
    end
  end

  def crear_archivo_de_costos
    @dis_log.info 'Creando archivo de costos en ' + Rails.root.to_s + '/' + SALIDA_TXT + '..'

    cantidad_marcadores = @costos.size

    `touch #{Rails.root.to_s + '/' + SALIDA_TXT}`

    File.open(Rails.root.to_s + '/' + SALIDA_TXT, 'w') do |file|
      for i in 0..(cantidad_marcadores - 1) do
        for j in 0..(cantidad_marcadores - 1) do
          file.write @matriz_costos[i][j]
          file.write ' '
        end
        file.write "\n"
      end
    end

    @dis_log.info 'Archivo de costos creado.'
  end

  def crear_archivo_de_duracion
    @dis_log.info 'Creando archivo de costos en ' + Rails.root.to_s + '/' + SALIDA_TXT_DURACION + '..'

    cantidad_marcadores = @duracion.size

    `touch #{Rails.root.to_s + '/' + SALIDA_TXT_DURACION}`

    File.open(Rails.root.to_s + '/' + SALIDA_TXT_DURACION, 'w') do |file|
      for i in 0..(cantidad_marcadores - 1) do
        for j in 0..(cantidad_marcadores - 1) do
          file.write @matriz_duracion[i][j]
          file.write ' '
        end
        file.write "\n"
      end
    end

    @dis_log.info 'Archivo de costos creado.'
  end

  def crear_archivo_de_bandera
    @dis_log.info 'Creando archivo de bandera en ' + Rails.root.to_s + '/' + BANDERA_TXT + '..'

    cantidad_marcadores = @costos.size

    `touch #{Rails.root.to_s + '/' + BANDERA_TXT}`

    File.open(Rails.root.to_s + '/' + BANDERA_TXT, 'w') do |file|
      file.write @bandera.to_s
      file.write "\n"
    end

    @dis_log.info 'Archivo de bandera creado.'
  end






  def metodo_deprecado
    ## Realizamos la consulta
    #http_response = HTTParty.get(BASE_URI + PATH_URI + parametros + END_URI)
    #json_response = JSON[http_response.body]
    #
    #if json_response['status'] == 'OK'
    #
    #  # Obtenemos el nombre y lo almacenamos
    #  NAMES.push(json_response['origin_addresses'][0])
    #
    #  # Obtenemos la distancia y la almacenamos
    #  distances = []
    #  json_response['rows'][0]['elements'].each do |destination|
    #    if destination['status'] == 'OK'
    #      distances.push(destination['distance']['value'])
    #    else
    #      @dis_log.info 'Ha ocurrido un error en la consulta puntual. El resultado es el siguiente: '
    #      @dis_log.info destination.to_hash.inspect
    #      @dis_log.info 'Para mas informacion: https://developers.google.com/maps/documentation/distancematrix/'
    #      @dis_log.info 'Las causas pueden ser: NOT_FOUND > La posicion no se puede localizar. ZERO_RESULTS No existe una ruta entre origen y destino.'
    #      return
    #    end
    #  end
    #  DISTANCES.push(distances)
    #
    #else
    #  @dis_log.info 'Ha ocurrido un error en la consulta:'
    #  @dis_log.info json_response.inspect
    #  @dis_log.info 'Para mas informacion: https://developers.google.com/maps/documentation/distancematrix/'
    #  @dis_log.info 'Las causas pueden ser: '
    #  @dis_log.info 'INVALID_REQUEST > Consulta erronea.'
    #  @dis_log.info 'MAX_ELEMENTS_EXCEEDED > Se excede el maximo por consulta.'
    #  @dis_log.info 'OVER_QUERY_LIMIT > Se han recibido muchas consultas desde esta IP en un corto periodo de tiempo.'
    #  @dis_log.info 'REQUEST_DENIED > Se prohibe el acceso de este sitio.'
    #  return
    #end
  end

end
