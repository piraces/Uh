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
desde el epositorio de puppet : https://forge.puppetlabs.com/ .