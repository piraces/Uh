#!/usr/bin/env ruby

# Autores: Raúl Piracés Alastuey - 490790, Luis Jesús Pellicer Magallón - 520256
# -----------------------------------------------------------------------------------
# Diseño e implementación de una herramienta de ejecución remota,
# despliegue y configuración automática.

# La configuración debe encontrarse en "~/.u/hosts" para una ejecución correcta.

# Comando p: ejecuta ping al puerto 22 a todas las máquinas establecidas en
# el fichero de configuración establecido (deben de ser nombres DNS o IPs).
# Este comando consta de un timeout por defecto de 0.01s.

# Comando s: ejecuta un comando remoto mediante ssh a todo el grupo de máquinas
# establecidas en el fichero de configuración (el comando debe de ir entre comillas).
# Si no se tienen claves ssh, se realiza petición de contraseña por pantalla.
# El usuario por defecto es a490790. El timeout para ssh por defecto son 10s.

# Comando c (de configuración) : aplica un manifiesto Puppet, que reside en el directorio
# ~/.u/manifiestos, en la máquinas selecionadas en el segundo parámetro. Si no se indica, 
# en este segundo parámetro, ningún grupo o máquina, se aplica a toda la lista de hosts 
# (de forma única para cada máquina que pueda estar en varios grupos).

# -----------------------------------------------------------------------------------
# Ejecución: u (p | s | c) ["comando" | "manifiesto"]
# Salida comando "p": máquina_<num>: FUNCIONA/falla. Una máquina por linea.
# Salida comando "s": máquina<num>: exito/fallo [stdout]. Una máquina por linea.
# Salida comando "c": máquina_<num>: exito en conexion/falla [stdout]. Una máquina por 
# linea.
require 'socket'
require 'timeout'
require 'net/ssh'
require 'net/scp'

# Variable para imprimir por pantalla el uso del script.
uso = "Ejecucion: u (p | s | c) \[\"comando\" | \"manifiesto\" \]"

# Variables principales de configuración del script.
confPath = "~/.u/hosts"
confManifiestos = ENV['HOME'] + "/.u/manifiestos/"
confModulos = ENV['HOME'] + "/.u/modulos/"
time = 0.01
timeSSH = 10
port = 22
user = "a490790"
noGroup = false
grupo = ARGV[0].to_s		
comando = ARGV[1].to_s
instruccion = ARGV[2].to_s
inGroup = false
used = false
resultado = ""

# Caso de ejecución sin argumentos.
if ARGV.length < 1 then
	print "No se ha introducido ningun argumento...\n"
	print uso, "\n"
elsif ARGV.length >= 1 then
	# Ajustes de variables de acuerdo al comando introducido (sin grupo).
	if ARGV[0].to_s == "p" || ARGV[0].to_s == "s" || ARGV[0].to_s == "c" then
		comando = ARGV[0].to_s
		instruccion = ARGV[1].to_s
		noGroup = true
	# Ajustes de variables de acuerdo al comando introducido (con grupo/maquina).
	elsif ARGV[1].to_s == "p" || ARGV[1].to_s == "s" || ARGV[1].to_s == "c" then
		grupo = ARGV[0].to_s		
		comando = ARGV[1].to_s
		instruccion = ARGV[2].to_s
	# Comandos no válidos (invocación erronea).
	else
		print "El comando introducido no es valido\n"
		print uso, "\n"
	end
	# Caso de comando correcto.
	if comando == "p" || comando == "s" || comando == "c" || comando == "n" then
		num = 1
		# Lectura de fichero.
		File.open(File.expand_path(confPath), "r") do |file|
			file.each_line do |line|
				# Gestión de grupos de máquinas, máquina de la lista (o lista entera).
				if line[0] == '-' then
					if (line[1..-2] == grupo) then
						inGroup = true
					else 
						inGroup = false
					end
				elsif ((noGroup == true) or (inGroup == true) or (line.strip == grupo)) and (line.strip != "")
					# Comando p: ping a máquina con timeout.
					if comando == "p" then
						error = 0
						begin
							begin
								# Ejecuta una petición al host y puerto con timeout
								Timeout.timeout(time) do 
								TCPSocket.open(line.chomp,port)
							end
							# Si ocurre cualquier error se hace saltar el timeout (porque falla).
							rescue Exception
								raise Timeout::Error
							end
						# Si el timeout se acaba, se imprime el mensaje de error.
						rescue Timeout::Error
							error = 1
							print "maquina_",num,": falla\n"
						end
						# Si el timeout no se acaba, se imprime el mensaje correcto.
						if error == 0 then 
							print "maquina_",num,": FUNCIONA\n"
						end
					# Comando s: ejecución remota por ssh.
					elsif (instruccion.length > 0) and (comando == "s") then
						begin
							# Comienza una sesión ssh, ejecuta el comando e imprime el resultado.
							Net::SSH.start(line.chomp, user, :timeout => timeSSH) do |session|
								resultado = session.exec!(instruccion)
								print "maquina",num,": exito\n",resultado,"\n"
							end
						# Si se produce cualquier error se imprime el mensaje de error.
						rescue Exception
							print "maquina",num,": falla\n"
						end
					# Comando c: aplicación remota de manifiestos Puppet.
					elsif (instruccion.length > 0) and (comando == "c") then
						begin
							resultado = ""
							# Comienza una sesión ssh, ejecuta el comando e imprime el resultado.
							Net::SSH.start(line.chomp, user, :timeout => timeSSH) do |session|
								timeStampPuppet = (Time.now.to_f * 1000).to_i
								# Copia temporal del fichero manifiesto a remoto.
								session.scp.upload! (confManifiestos + instruccion), (timeStampPuppet.to_s + instruccion)
								# Ejecución remota de la aplicación del manifiesto y recuperación de salida.
								# Borrado remoto del manifiesto (temporal).
								resultado = session.exec!("puppet apply " + timeStampPuppet.to_s + instruccion + ";" + 
																"rm -rf " + timeStampPuppet.to_s + instruccion)
								print "maquina",num,": exito en conexion\n",resultado,"\n"
								used = true
							end
						# Si se produce cualquier error se imprime el mensaje de error.
						rescue Exception
							print "maquina",num,": falla\n"
						end
					# Comando n: automatizar la configuración de clientes ntp, dns y nfs mediante módulos puppet
					elsif (instruccion.length > 0) and (comando == "n") then
						begin
							resultado = ""
							# Comienza una sesión ssh, ejecuta el comando e imprime el resultado.
							Net::SSH.start(line.chomp, user, :timeout => timeSSH) do |session|
							timeStampPuppet = (Time.now.to_f * 1000).to_i
							# Copia temporal del fichero manifiesto a remoto.
							session.scp.upload! (confModulos + instruccion), (timeStampPuppet.to_s + instruccion)
							session.scp.upload! (confManifiestos + "confIpaClient"), (timeStampPuppet.to_s + "confIpaClient")
							resultado = session.exec!("puppet apply module install" +timeStampPuppet.to_s ")
							resultado = session.exec!("puppet apply " + timeStampPuppet.to_s + instruccion + ";" + 
									"rm -rf " + timeStampPuppet.to_s + instruccion)
					# Comando s/c sin comando/manifiesto remoto a ejecutar.
					else
						print "No se ha introducido ningun comando o manifiesto...\n"
						print uso, "\n"
					end
					num += 1
				end
			   end
			end
			# Borrado de fichero local de manifiesto (comando c solo)
			if (instruccion.length > 0) and (comando == "c") and used then
				File.delete(confManifiestos + instruccion)
			end
		end
# Caso de comando no válido.
else
	print "El comando introducido no es valido\n"
	print uso, "\n"
end
