# RedStat

A new user interface for the open-source potentiostat [dstat](https://doi.org/10.1371/journal.pone.0140349).

The user interface is written in Javascript using node-red. This repository consists of an installation [script](https://raw.githubusercontent.com/CarlosSanchez01/RedStat/main/script.sh) designed to be run in a raspberry pi:

```bash
pi@hostname:~$ wget https://raw.githubusercontent.com/CarlosSanchez01/RedStat/main/script.sh
pi@hostname:~$ sudo script.sh
```

This will install the tools grafana, influxdb and node-red