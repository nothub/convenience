Quick and easy local Minecraft server deployment.

---

##### Usage

```
usage: server-setup.py [-h] [-f NAME] [-mc VERSION] [-p PORT] [-d PATH] [-ln NAME] [-cp PATH [PATH ...]]

optional arguments:
  -h, --help            show this help message and exit
  -f NAME, --fork NAME  server fork (paper, tuinity, airplane)
  -mc VERSION, --mc-version VERSION
                        mc version (paper only)
  -p PORT, --port PORT  server port
  -d PATH, --server-dir PATH
                        server dir path
  -ln NAME, --link-name NAME
                        server link name
  -cp PATH [PATH ...], --copy-plugins PATH [PATH ...]
                        copy to plugin dir (* is wildcard)
```

---

`./server-setup.py -mc 1.12.2 -d test-server -ln srv.jar`

`./server-setup.py --fork airplane -p 25566 --copy-plugins Foo.jar target/Bar-*.jar`

---

[maven integration example](MAVEN.md)
