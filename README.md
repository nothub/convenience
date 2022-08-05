Download (and provision) Minecraft servers from the papermc.io api.

---

##### Usage

```
Usage: convenience [-d=<path>] [-a=<path>] [-p=<port>] [-i=<path>...] [-v] [-h|-?] [--] [version] [build]

By default, the latest possible server release will be used.

Options:
  -d <path>    Server directory       [default: server]
  -a <path>    Server alias           [default: {{server}}/server.jar]
  -p <port>    Server port            [default: 25565]
  -i <path>    Plugin jar to install  (multiple possible)
  -v           Enable verbose output
  -h, -?       Print help and exit

Examples:
  convenience 1.12.2 1337
  convenience -v 1.15
  convenience -d srv
  convenience -d /opt/srv
  convenience -a foo.jar
  convenience -a /home/user/bar.jar
  convenience -p 9001
  convenience -i foo.jar -i rel/bar.jar -i /abs/test.jar
  convenience -i https://example.org/foo/bar.jar
```

---

[maven integration example](MAVEN.md)
