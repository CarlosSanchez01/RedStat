# RedStat

A new user interface for the open-source potentiostat [dstat](https://doi.org/10.1371/journal.pone.0140349).

The user interface is written in Javascript using node-red. This repository consists of an installation [script](https://raw.githubusercontent.com/CarlosSanchez01/RedStat/main/script.sh) designed to be run in a raspberry pi.

Initially the raspberry pi will require to flash the operative system in the sd card using [raspberry pi imager](https://www.raspberrypi.org/software/) or similar [alternatives](https://rufus.ie/).

Then, 2 files need to be created in the boot partition inside the sd card to allow [headless](https://www.raspberrypi.org/documentation/configuration/wireless/headless.md) raspberry pi connection:

1. file called **ssh** file to allow ssh connection at first boot
2. another file, this one called **wpa_supplicant.conf** with the contents of the wifi connection of your router. The format of this file is the following:

        ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
        update_config=1
        country="country code"

        network={
            ssid="your network"
            psk="your password"
        }

After this, the raspberry pi can be turned on and it will connect to the wifi network. However, it is important to consider that RPi3b+ only uses 2.4GHz which means that it makes sense to have an access point router like [Tplink nano](https://www.tp-link.com/us/home-networking/wifi-router/tl-wr802n/) to facilitate connection of all the raspberry pis that you want to use on your setup.

Then you can connect to your Raspberry pi
```bash
user@yourclient:~$ ssh pi@<Ip address of your raspberry pi>
```
after you logged in with the default password "raspberry" you are logged in and you can download and run the installation [script](https://raw.githubusercontent.com/CarlosSanchez01/RedStat/main/script.sh).

```bash
pi@hostname:~$ wget https://raw.githubusercontent.com/CarlosSanchez01/RedStat/main/script.sh
pi@hostname:~$ sudo script.sh
```

This will first set new hostname for your raspberry pi, change the default password, set ssh as a service and then install the tools required:

- grafana
- influxdb (and create default "dstat" database)
- node-red (and node dependencies)

Facilitating the installation process and allowing easy handling of data in a client-server infrastructure.

Now you can open your node-red and paste the flows.