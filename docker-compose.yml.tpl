version: '3.4'

services:
  takserver:
    image: pvarki/takserver:4.10-RELEASE-12
    build:
      context: .
      dockerfile: Dockerfile
    env_file:
      - 'takserver.env'
    depends_on:
      - "takdb"
    volumes:
      - 'takserver_logs:/opt/tak/data/logs'
      - 'takserver_certs:/opt/tak/data/certs'
    networks:
      - taknet
    ports:
      - '8443:8443'
      - '8444:8444'
      - '8446:8446'
      - '8089:8089'

  certapi:
    image: pvarki/takserver:certsapi-latest
    build:
      target: production
      context: .
      dockerfile: python-takcertsapi/Dockerfile
    env_file:
      - 'takserver.env'
    depends_on:
      - "takserver"
    volumes:
      - 'takserver_certs:/opt/tak/data/certs'
    networks:
      - taknet
    expose:
      - 8000
    ports:
      - "8000:8000"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fastapi.rule=Host(`{{.Env.TAK_SERVER_ADDRESS}}`)"
      - "traefik.http.routers.fastapi.tls=true"
      - "traefik.http.routers.fastapi.tls.certresolver=letsencrypt"

  traefik:
    image: traefik:v2.2
    networks:
      - taknet
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "$PWD/traefik.toml:/etc/traefik/traefik.toml"

  takdb:
    image: postgis/postgis:15-3.3
    networks:
      - taknet
    env_file:
      - 'takserver.env'
    volumes:
      - 'takdb_data:/var/lib/postgresql/data'

networks:
  taknet:

volumes:
  takdb_data:
    driver: local
  takserver_logs:
    driver: local
  takserver_certs:
    driver: local
