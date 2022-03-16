# Clase 3 – Herramientas de Gestión de Red. Pt. 1

En esta clase iniciaremos la administración de una red Linux con los comandos de la suite
iproute2.

Haremos uso de la ‘Virtualización’ para construir una arquitectura ‘cliente-servidor’ local. En ella, vamos a utilizar diversas herramientas de networking para:
- Comprender los conceptos básicos de administración de redes en Linux.
- Ejecutar comandos que configuran el comportamiento de un servidor Linux en red.

## 1 Denominación de las interfaces de red

Algunas versiones de Linux etiquetan , directamente por el kernel, a las interfaces de red con la convención `<eth><numero de interface>` o `<wlan><numero de interface>`, que en la praxis lleva a imponderables innecesarios debido una generalidad que especificaba muy poco, salvo si esta interfaz era para conexión utp o wifi.

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:21:cc:cd:83:61 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.4/24 brd 192.168.1.255 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::d984:6556:b217:4fd9/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
3: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether de:89:f1:ad:eb:2d brd ff:ff:ff:ff:ff:ff
```

La denominación que aplica [systemd](https://es.wikipedia.org/wiki/Systemd) a las interfaces de red, viene dada por directivas basadas en un esquema que fija el nombre de la interfaz según la posición que ocupa en el arreglo bus de la tarjeta.

Asi:

I. Si los nombres que incorporan el Firmware/BIOS proporcionan los números de índices para los dispositivos conectados (ejemplo, en01), se aplica esa información.

II. Si el punto anterior falla, los nombres que incorporan el Firmware/BIOS proporcionan los números de las ranuras PCI Express (ejemplo, ens1), entonces se aplica esa información.

III. Si el punto anterior falla systemd verifica si el hardware incorpora información de ubicación física del conector (ejemplo, enp2s0) y se aplica esta política.

IV. Si fallan todas las anteriores, se utiliza la nomenclatura tradicional del kernel.

```
root@telematicaadmredes:~# ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:a2:8c:94 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.7/24 brd 192.168.1.255 scope global enp0s3
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fea2:8c94/64 scope link 
       valid_lft forever preferred_lft forever
```

La conveniencia de utilizar denominaciones en lugar de direcciones ip es aplicado ampliamente en la administración de redes. Para tal fin, los servidores DNS proveen un mecanismo claro y directo de asociación entre un dispositivo y su nombre en la red. Sin embargo, no es, necesariamente, el DNS el primer lugar donde un host Linux acude para la resolucón de nombres. Existe un archivo en el filesystem que el sistema verificará inicialmente y este es: `/etc/hosts/`.

```
root@telematicaadmredes:~# cat /etc/hosts
127.0.0.1       localhost
127.0.1.1       telematicaadmredes

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

En el archivo host de nuestro servidor Linux, vemos la denominación de ‘localhost’ a la dirección de loopback. Si hacemos ping a la denominación asignada en el archivo host, veremos que localmente resuelve el nombre de si mismo.

```
root@telematicaadmredes:~# ping telematicaadmredes
PING telematicaadmredes (127.0.1.1) 56(84) bytes of data.
64 bytes from telematicaadmredes (127.0.1.1): icmp_seq=1 ttl=64 time=0.084 ms
64 bytes from telematicaadmredes (127.0.1.1): icmp_seq=2 ttl=64 time=0.116 ms
64 bytes from telematicaadmredes (127.0.1.1): icmp_seq=3 ttl=64 time=0.117 ms
64 bytes from telematicaadmredes (127.0.1.1): icmp_seq=4 ttl=64 time=0.117 ms
64 bytes from telematicaadmredes (127.0.1.1): icmp_seq=5 ttl=64 time=0.116 ms
^C
--- telematicaadmredes ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4011ms
rtt min/avg/max/mdev = 0.084/0.110/0.117/0.013 ms
```

En el archivo de configuración etc/nsswitch.conf (Name Service Switch configuration) se encuentra la forma en que el sistema fija la prioridad sobre quien asignara el hostname del servidor, si es el archivo hosts o el servidor DNS.

```
root@telematicaadmredes:~# cat /etc/nsswitch.conf


# /etc/nsswitch.conf
#
# Example configuration of GNU Name Service Switch functionality.
# If you have the `glibc-doc-reference' and `info' packages installed, try:
# `info libc "Name Service Switch"' for information about this file.

passwd:         compat
group:          compat
shadow:         compat
gshadow:        files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
```

Interpretando las directivas en el archivo, vemos que el sistema debe primero verificar el archivo /etc/hosts y darle prioridad a la denominación de nuestro sistema alli contenida.

## 2 Iproute2
La administración de redes en un sistema Linux ha sido por mucho tiempo net-tools y aun viene instalado en algunas distribuciones. Sin embargo, la falta de soporte del paquete ha dado lugar al desarrollo de iproute2, volviendose este, sistematicamente en la herramienta de gestión por defecto en Linux.

A partir de este momento, en este curso, solo usaremos iproute2.

## 3 Herramientas de Gestión


| Comando iproute2                                         | Descripción                                                                                                                                                                                                         | Descripción                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
|----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| man ip ip --help                                         | Invocar la ayuda de iproute2                                                                                                                                                                                        | Usage: ip [ OPTIONS ] OBJECT { COMMAND \| help } ip [ -force ] -batch filename .. ...                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ip a ip address ip addr list ip link show ip a show eth0 | Listar las interfaces de red                                                                                                                                                                                        |```root@telematicaadmredes:~# ip address 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00     inet 127.0.0.1/8 scope host lo        valid_lft forever preferred_lft forever     inet6 ::1/128 scope host         valid_lft forever preferred_lft forever 2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000     link/ether 08:00:27:a2:8c:94 brd ff:ff:ff:ff:ff:ff     inet 192.168.1.7/24 brd 192.168.1.255 scope global enp0s3        valid_lft forever preferred_lft forever     inet6 fe80::a00:27ff:fea2:8c94/64 scope link         valid_lft forever preferred_lft forever ``` |
| ip link set eth0 up ip link set eth0 down                | Activar/Desactivar interfaz de red                                                                                                                                                                                  |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ip monitor all                                           | Supervisa los cambios acaecidos en la tabla de enrutamiento, direcciones, interfaces, tablas ARP. Muy usado en la planificación y monitoreo de infraestructura de servicios en Máquinas virtuales y/o contenedores. | ```root@telematicaadmredes:~# ip monitor all  [nsid current]192.168.1.4 dev enp0s3 lladdr 00:21:cc:cd:83:61 REACHABLE [nsid current]192.168.1.4 dev enp0s3 lladdr 00:21:cc:cd:83:61 STALE [nsid current]192.168.1.4 dev enp0s3 lladdr 00:21:cc:cd:83:61 STALE [nsid current]192.168.1.4 dev enp0s3 lladdr 00:21:cc:cd:83:61 PROBE [nsid current]192.168.1.4 dev enp0s3 lladdr 00:21:cc:cd:83:61 REACHABLE ```                                                                                                                                                                                                 |