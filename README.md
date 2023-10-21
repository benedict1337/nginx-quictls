
# **NGINX** Docker built with **QuicTLS**

A simple NGINX Docker image compiled with **QuicTLS**.


## Features

- **QuicTLS**
- **HTTP/3 QUIC** and **0-RTT** support
- **Dynamic TLS** records patch support
- **Brotli** support
- **GeoIP2** support
- **NJS** support
- **ModSecurity** support



## Deployment

To deploy this docker image run

```bash
docker run -d --restart unless-stopped -p 80:80 -p 443:443 -p 443:443/udp -v ./nginx-config:/etc/nginx benedicthu/nginx-quictls
```

Docker-Compose

```yaml
version: '3.9'
services:
    nginx-quictls:
        image: benedicthu/nginx-quictls
        volumes:
            - './nginx-config:/etc/nginx'
        ports:
            - '443:443/udp'
            - '443:443'
            - '80:80'
        restart: unless-stopped
```
## License

[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://opensource.org/licenses/)

