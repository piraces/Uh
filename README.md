# U
Herramienta de ejecución remota, despliegue y configuración automática.

Se trata de una expansión de la Tarea 2 de ASIS2.
Como el método principal ya tiene demasiados apartados, conviene la creación de metodos para las nuevas funcionalidades añadidas.

Todos las nuevas funcionalidades añadidas deben de ser anotadas en el fichero "changelog.txt" y puestas en métodos adicionales, llamándolos desde el método principal.

# Objetivos

Automatizar la configuración de clientes ntp, dns y nfs mediante la herramienta u, Puppet y Ruby de las máquinas que
lo necesiten en las subredes 2001:470:736b:211::/64 y 2001:470:736b:212::/64.

Para ello, adaptar la herramienta "u" para que se pueda pasar como parámetro, no un manifiesto sino una secuencia
de modulos Puppet a aplicar en la máquinas remotas ( o grupos) definidas en el fichero de configuración de " u".
Estos modulos estarán ya creados en el subdirectorio "modulos" del directorio ".u". Se pueden descargar modulos
desde el epositorio de puppet : https://forge.puppetlabs.com/.

# Configuración y uso:
La configuracion debe encontrarse en "~/.u/hosts" para una ejecucion correcta.

- Comando p: ejecuta ping al puerto 22 a todas las maquinas establecidas en
el fichero de configuracion establecido (deben de ser nombres DNS o IPs).
Este comando consta de un timeout por defecto de 0.01s.

- Comando s: ejecuta un comando remoto mediante ssh a todo el grupo de maquinas
establecidas en el fichero de configuracion (el comando debe de ir entre comillas).
Si no se tienen claves ssh, se realiza peticion de contraseña por pantalla.
El usuario por defecto es a490790. El timeout para ssh por defecto son 10s.

- Comando c (de configuracion) : aplica un manifiesto Puppet, que reside en el directorio
~/.u/manifiestos, en la maquinas selecionadas en el segundo parametro. Si no se indica, 
en este segundo parametro, ningún grupo o maquina, se aplica a toda la lista de hosts 
(de forma única para cada maquina que pueda estar en varios grupos).

- Comando n: configura un cliente ntp,dns y nfs (freeipa) mediante modulos puppet en las
maquinas seleccionadas en el segundo parametro. Los modulos puppet residen en en subdirectorio
~/.u/modulos.

# Ejecución y salidas:

- Ejecucion: u (p | s | c | n) ["comando" | "manifiesto"]
- Salida comando "p": maquina_<num>: FUNCIONA/falla. Una maquina por linea.
- Salida comando "s": maquina<num>: exito/fallo [stdout]. Una maquina por linea.
- Salida comando "c": maquina_<num>: exito en conexion/falla [stdout]. Una maquina por 
- linea.
- Salida comando "n": maquina_<num>: exito en configuracion [stdout]. Una maquina por
- linea.
