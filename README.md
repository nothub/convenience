Download (and provision) Minecraft servers from the papermc.io api.

---

##### Usage

```
Usage: paperdl [-d=<path>] [-p=<port>] [-a=<path>] [-i=<path>...] [-v] [-h|-?] [--] [version] [build]

By default, the latest possible server release will be used.

Options:
  -d <path>    Server directory       [default: server]
  -p <port>    Server port            [default: 25565]
  -a <path>    Server alias           [default: {{server}}/server.jar]
  -i <path>    Plugin jar to install  (multiple possible)
  -v           Enable verbose output
  -h, -?       Print help and exit

Examples:
  paperdl 1.12.2 1337
  paperdl -v 1.15
  paperdl -d srv
  paperdl -d /opt/srv
  paperdl -p 9001
  paperdl -a foo.jar
  paperdl -a "/home/user/bar.jar"
  paperdl -i foo.jar -i rel/bar.jar -i /abs/test.jar
```

---

[maven integration example](MAVEN.md)
