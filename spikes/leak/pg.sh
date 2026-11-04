#!/usr/bin/env bash
# Private throwaway Postgres 16 cluster for spike 1.
# Data lives in spikes/leak/.pgdata (gitignored). Listens on 127.0.0.1:55432 only.
# Never touches any other cluster, the default port 5432, or brew services.
#
#   ./pg.sh start   create the cluster if missing, then start it
#   ./pg.sh stop    stop it
#   ./pg.sh reset   stop, delete .pgdata, create and start a fresh cluster
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PGBIN="$(brew --prefix postgresql@16)/bin"
DATA="$HERE/.pgdata"
PORT=55432
LOG="$DATA/server.log"
# Without a valid LC_ALL the macOS postmaster aborts with
# "postmaster became multithreaded during startup".
export LC_ALL=C

init() {
  "$PGBIN/initdb" --pgdata="$DATA" --username=spike --auth=trust \
    --encoding=UTF8 --locale=C --no-instructions >/dev/null
  # Config edits stay inside this data dir.
  {
    echo "listen_addresses = '127.0.0.1'"
    echo "port = $PORT"
    echo "unix_socket_directories = '$DATA'"
  } >>"$DATA/postgresql.conf"
}

start() {
  [ -f "$DATA/PG_VERSION" ] || init
  if "$PGBIN/pg_ctl" --pgdata="$DATA" status >/dev/null 2>&1; then
    echo "already running on 127.0.0.1:$PORT"
    return
  fi
  "$PGBIN/pg_ctl" --pgdata="$DATA" --log="$LOG" --wait start >/dev/null
  "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U spike -d postgres -qtAc \
    "select 1 from pg_database where datname = 'leak'" | grep -q 1 ||
    "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U spike -d postgres -qc "create database leak"
  echo "running on 127.0.0.1:$PORT (database leak, user spike)"
}

stop() {
  if [ -f "$DATA/PG_VERSION" ] && "$PGBIN/pg_ctl" --pgdata="$DATA" status >/dev/null 2>&1; then
    "$PGBIN/pg_ctl" --pgdata="$DATA" --wait --mode=fast stop >/dev/null
    echo "stopped"
  else
    echo "not running"
  fi
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  reset) stop; rm -rf "$DATA"; start ;;
  *) echo "usage: $0 start|stop|reset" >&2; exit 2 ;;
esac
