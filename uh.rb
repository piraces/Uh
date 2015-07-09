#!/usr/bin/env ruby

# Autores: Raúl Piraces Alastuey - 490790, Luis Jesús Pellicer Magallon - 520256
# -----------------------------------------------------------------------------------
# Diseño e implementacion de una herramienta de ejecucion remota,
# despliegue y configuracion automatica.

# La configuracion debe encontrarse en "~/.uh/hosts" para una ejecucion correcta.

# Comando p: ejecuta ping al puerto 22 a todas las maquinas establecidas en
# el fichero de configuracion establecido (deben de ser nombres DNS o IPs).
# Este comando consta de un timeout por defecto de 0.01s.

# Comando s: ejecuta un comando remoto mediante ssh a todo el grupo de maquinas
# establecidas en el fichero de configuracion (el comando debe de ir entre comillas).
# Si no se tienen claves ssh, se realiza peticion de contraseña por pantalla.
# El usuario por defecto es a490790. El timeout para ssh por defecto son 10s.

# Comando c (de configuracion) : aplica un manifiesto Puppet, que reside en el directorio
# ~/.uh/manifiestos, en la maquinas selecionadas en el segundo parametro. Si no se indica,
# en este segundo parametro, ningún grupo o maquina, se aplica a toda la lista de hosts
# (de forma única para cada maquina que pueda estar en varios grupos).

# Comando n: configura un cliente ntp,dns y nfs (freeipa) mediante modulos puppet en las
# maquinas seleccionadas en el segundo parametro. Los modulos puppet residen en en subdirectorio
# ~/.uh/modulos.

# -----------------------------------------------------------------------------------
# Ejecucion: uh [grupo] (p | s | c | n) ["comando" | "manifiesto"]
# Salida comando "p": maquina_<num>: FUNCIONA/falla. Una maquina por linea.
# Salida comando "s": maquina<num>: exito/fallo [stdout]. Una maquina por linea.
# Salida comando "c": maquina_<num>: exito en conexion/falla [stdout]. Una maquina por
# linea.
# Salida comando "n": maquina_<num>: exito en configuracion [stdout]. Una maquina por
# linea.
require 'socket'
require 'timeout'
require 'net/ssh'
require 'net/scp'

class Uh
	# Variable para imprimir por pantalla el uso del script.
	$uso = "Ejecucion: uh [grupo] (p | s | c | n) \[\"comando\" | \"manifiesto\" \]"

	# Variables principales de configuracion del script.
	$confPath = "~/.uh/hosts"
	$confManifiestos = ENV['HOME'] + "/.uh/manifiestos/"
	$confModulos = ENV['HOME'] + "/.uh/modulos/"
	$time = 0.01
	$timeSSH = 10
	$port = 22
	$user = "root"
	$noGroup = false
	$grupo = ARGV[0].to_s
	$comando = ARGV[1].to_s
	$instruccion = ARGV[2].to_s
	$inGroup = false
	$used = false
	$resultado = ""
	$iteracion = 0
	$iteracion2 = 0

	# Ajuste de variables y comprobación de los casos de ejecución.
	def self.get_arguments
		# Caso de ejecucion sin argumentos.
		if ARGV.length < 1 then
			print "No se ha introducido ningun argumento...\n"
			print $uso, "\n"
			return 1
		elsif ARGV.length >= 1 then
			# Ajustes de variables de acuerdo al comando introducido (sin grupo).
			if ARGV[0].to_s == "p" || ARGV[0].to_s == "s" || ARGV[0].to_s == "c" || ARGV[0].to_s == "n" then
				$comando = ARGV[0].to_s
				$instruccion = ARGV[1].to_s
				$iteracion = 1
				$iteracion2 = 1
				$noGroup = true
				return 0
			# Ajustes de variables de acuerdo al comando introducido (con grupo/maquina).
			elsif ARGV[1].to_s == "p" || ARGV[1].to_s == "s" || ARGV[1].to_s == "c" || ARGV[1].to_s == "n" then
				$grupo = ARGV[0].to_s
				$comando = ARGV[1].to_s
				$instruccion = ARGV[2].to_s
				$iteracion = 2
				$iteracion2 = 2
				return 0
			# Comandos no validos (invocacion erronea).
			else
				print "El comando introducido no es valido\n"
				print $uso, "\n"
				return 1
			end
		end
	end

	# lee el fichero "hosts" y solicita la ejecución del comando para cada linea de
	# "hosts" elegida.
	def self.read_execute
		$num = 1
		# Lectura de fichero.
		File.open(File.expand_path($confPath), "r") do |file|
			file.each_line do |line|
				# Gestion de grupos de maquinas, maquina de la lista (o lista entera).
				if line[0] == '-' then
					if (line[1..-2] == $grupo) then
						$inGroup = true
					else
						$inGroup = false
					end
				elsif (($noGroup == true) or ($inGroup == true) or (line.strip == $grupo)) and (line.strip != "")
					do_execute(line)
				end
			end
		end
	end

	# Identifica el tipo de comando y lo ejecuta para cada linea (máquina).
	def self.do_execute(linea)
						# Comando p: ping a maquina con timeout.
						if $comando == "p" then
							do_ping(linea)
						# Comando s: ejecucion remota por ssh.
					elsif ($instruccion.length > 0) and ($comando == "s") then
							do_command(linea)
						# Comando c: aplicacion remota de manifiestos Puppet.
					elsif ($instruccion.length > 0) and ($comando == "c") then
							do_puppet(linea)
						# Comando n: automatizar la configuracion de clientes ntp, dns y nfs mediante modulos puppet
					elsif ($instruccion.length > 0) and ($comando == "n") then
							do_configure(linea)
							# Comando s/c/n sin comando/manifiesto remoto a ejecutar.
						else
								print "No se ha introducido ningun comando, manifiesto o modulo \n"
								print $uso, "\n"
						end
						$num += 1
	end


	# Comando p: ping a maquina con timeout.
	def self.do_ping(line)
		error = 0
		begin
			begin
				# Ejecuta una peticion al host y puerto con timeout
				Timeout.timeout($time) do
				TCPSocket.open(line.chomp,$port)
			end
			# Si ocurre cualquier error se hace saltar el timeout (porque falla).
			rescue Exception
				raise Timeout::Error
			end
		# Si el timeout se acaba, se imprime el mensaje de error.
		rescue Timeout::Error
			error = 1
			print "maquina_",$num,": falla\n"
		end
		# Si el timeout no se acaba, se imprime el mensaje correcto.
		if error == 0 then
			print "maquina_",$num,": FUNCIONA\n"
		end
	end

	# Comando s: ejecucion remota por ssh.
	def self.do_command(line)
		begin
			# Comienza una sesion ssh, ejecuta el comando e imprime el resultado.
			Net::SSH.start(line.chomp, $user, :timeout => $timeSSH) do |session|
				resultado = session.exec!($instruccion)
				print "maquina",$num,": exito\n",resultado,"\n"
			end
		# Si se produce cualquier error se imprime el mensaje de error.
		rescue Exception
			print "maquina",$num,": falla\n"
		end
	end

	# Comando c: aplicacion remota de manifiestos Puppet.
	def self.do_puppet(line)
		begin
			resultado = ""
			# Comienza una sesion ssh, ejecuta el comando e imprime el resultado.

			Net::SSH.start(line.chomp, $user, :timeout => $timeSSH) do |session|
				while iteracion < ARGV.length do
					$instruccion = ARGV[$iteracion]
					timeStampPuppet = (Time.now.to_f * 1000).to_i
					# Copia temporal del fichero manifiesto a remoto.
					session.scp.upload! ($confManifiestos + $instruccion), (timeStampPuppet.to_s + $instruccion)
					# Ejecucion remota de la aplicacion del manifiesto y recuperacion de salida.
					# Borrado remoto del manifiesto (temporal).
					resultado = session.exec!("puppet apply " + timeStampPuppet.to_s + $instruccion + ";" +
													"rm -rf " + timeStampPuppet.to_s + $instruccion)
					print "maquina",$num,": exito en conexion\n",resultado,"\n"
					used = true
					$iteracion = $iteracion + 1
				end
			end
		# Si se produce cualquier error se imprime el mensaje de error.
		rescue Exception
			print "maquina",$num,": falla\n"
		end
		# Borrado de ficheros locales de manifiestos (comando c solo)
		if ($instruccion.length > 0) and ($comando == "c") and used then
			while $iteracion2 < ARGV.length do
				$instruccion = ARGV[$iteracion2]
				File.delete($confManifiestos + $instruccion)
				$iteracion2 = $iteracion2 + 1
			end
		end
	end

	# Comando n: automatizar la configuracion de clientes ntp, dns y nfs mediante modulos puppet
	def self.do_configure(line)
		begin
			resultado = ""
			# Comienza una sesion ssh, ejecuta el comando e imprime el resultado.

			Net::SSH.start(line.chomp, $user, :timeout => $timeSSH) do |session|

				num_vlan = line.chomp[34..34]

				# Copia temporal de los modulos a remoto.
				#print "Descargando el paquete ipa en el cliente\n"
				#session.exec!("yum -y install ipa-client ipa-admintools")
				print "Transfiriendo modulos puppet al nuevo cliente.\n"
				session.scp.upload! ($confModulos + "stbenjam-ipaclient-2.4.1.tar.gz"), ("/tmp/stbenjam-ipaclient-2.4.1.tar.gz")
				session.scp.upload! ($confModulos + "puppetlabs-stdlib-4.6.0.tar.gz"), ("/tmp/puppetlabs-stdlib-4.6.0.tar.gz")

				print "Transfiriendo manifiesto de configuracion del freeipa\n"
				# Copia temporal del manifiesto de arranque a remoto.
				session.scp.upload! ($confManifiestos + "confIpaClient.pp"), ("/tmp/" + "confIpaClient.pp")
				print "Configurando la red en el cliente\n"
				#Configurar la red deshabilitando la interfaz por defecto y añadiendo la vlan212.
				session.exec!("sed -i 's/IPV6_AUTOCONF=\"yes\"/IPV6_AUTOCONF=\"no\"/g' /etc/sysconfig/network-scripts/ifcfg-ens3")
				session.exec!("echo \"DEVICE=ens3.21"+num_vlan + "\" > /etc/sysconfig/network-scripts/ifcfg-ens3.21" + num_vlan)
				session.exec!("echo \"BOOTPROTO=none\" >> /etc/sysconfig/network-scripts/ifcfg-ens3.21" + num_vlan)
				session.exec!("echo \"IPV6INIT=yes\" >> /etc/sysconfig/network-scripts/ifcfg-ens3.21" + num_vlan)
				session.exec!("echo \"IPV6_AUTOCONF=yes\" >> /etc/sysconfig/network-scripts/ifcfg-ens3.21" + num_vlan)
				session.exec!("echo \"IPV6_DEFAULTGW=2001:470:736b:21"+num_vlan+"::1\" >> /etc/sysconfig/network-scripts/ifcfg-ens3.21" + num_vlan)
				session.exec!("echo \"DNS1=2001:470:736b:211:5054:ff:fe02:1102\" >> /etc/sysconfig/network-scripts/ifcfg-ens3.21" + num_vlan)
				session.exec!("echo \"DNS1=2001:470:736b:211:5054:ff:fe02:1103\" >> /etc/sysconfig/network-scripts/ifcfg-ens3.21" + num_vlan)
				session.exec!("echo \"VLAN=yes\" >> /etc/sysconfig/network-scripts/ifcfg-ens3.21" + num_vlan)
				print "Cambiando el nombre en el fichero hostname\n"
				# Cambiar el nombre en localhost
				num_maquina = line.chomp[35..35]
				session.exec!("echo \"cliente" + num_maquina+".1.2.ff.es.eu.org\" > /etc/hostname")
				# Reiniciar la maquina e instalar modulos puppet.
				print "Reiniciando la maquina\n"
				session.exec!("shutdown -r now")
			end
		rescue Exception
			print "Esperando a que la maquina se reinicie\n"
			# Esperar a que la máquina se levante.
			sleep 40
			num_maquina = line.chomp[35..35]
			num_vlan = line.chomp[34..34]
			direccion_nueva = "2001:470:736b:21"+ num_vlan + ":5054:ff:fe1f:21"+ num_vlan + num_maquina
			print "Conectando a traves de la nueva interfaz\n"
			Net::SSH.start(direccion_nueva, $user, :timeout => $timeSSH) do |session2|

				print "Instalando modulos puppet.\n"
				# Intalacion de los modulos puppet.
				resultado = session2.exec!("puppet module install " + "/tmp/puppetlabs-stdlib-4.6.0.tar.gz --ignore-dependencies")
				print resultado
				resultado = session2.exec!("puppet module install " + "/tmp/stbenjam-ipaclient-2.4.1.tar.gz --ignore-dependencies")
				print resultado
				print "Configurando freeipa\n"
				# Configuracion automatica de la maquina.
				resultado = session2.exec!("puppet apply --debug /tmp/" + "confIpaClient.pp")
				print resultado

				print "Borrando ficheros temporales"
				sleep 20
				# Borrado de los ficheros temporales.
				resultado = session2.exec!("rm -rf " + "/tmp/stbenjam-ipaclient-2.4.1.tar.gz")
				resultado = session2.exec!("rm -rf " + "/tmp/puppetlabs-stdlib-4.5.0.tar.gz")
				resultado = session2.exec!("rm -rf /tmp/" + "confIpaClient.pp")
			end
			end
	end
end

# Ejecución completa del script.
if(Uh.get_arguments != 1)
	Uh.read_execute
end
