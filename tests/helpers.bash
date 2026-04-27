setup_temp_repo() {
  TMP_REPO="$(mktemp -d)"
  cd "$TMP_REPO"
  git init -q
  git config user.email t@t.local
  git config user.name t
}

teardown_temp_repo() {
  cd /
  rm -rf "$TMP_REPO"
}

# Source library files relative to repo root.
source_lib() {
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests*}"
  source "$REPO_ROOT/lib/config.sh"
}

# Spin up a simple mock kanban server using python http.server.
# Returns the URL via $MOCK_KANBAN_URL and writes a request log to $MOCK_KANBAN_LOG.
start_mock_kanban() {
  MOCK_KANBAN_DIR="$(mktemp -d)"
  MOCK_KANBAN_LOG="$MOCK_KANBAN_DIR/requests.log"
  MOCK_KANBAN_PORT=$((20000 + RANDOM % 10000))
  MOCK_KANBAN_URL="http://127.0.0.1:$MOCK_KANBAN_PORT"

  python3 -c "
import http.server, json, sys, threading
log_path = '$MOCK_KANBAN_LOG'

class H(http.server.BaseHTTPRequestHandler):
    def _log(self, body):
        with open(log_path, 'a') as f:
            f.write(json.dumps({'method': self.command, 'path': self.path, 'headers': dict(self.headers), 'body': body}) + '\n')
    def do_POST(self):
        n = int(self.headers.get('content-length', '0'))
        body = self.rfile.read(n).decode('utf-8') if n else ''
        self._log(body)
        if self.path == '/api/cards':
            self.send_response(201); self.send_header('content-type','application/json'); self.end_headers()
            self.wfile.write(b'{\"id\":\"c_mock\",\"title\":\"mock\",\"project\":\"mock\",\"status\":\"in_progress\",\"tags\":[]}')
        elif self.path.startswith('/api/cards/') and self.path.endswith('/activity'):
            self.send_response(201); self.send_header('content-type','application/json'); self.end_headers()
            self.wfile.write(b'{\"ok\":true}')
        else:
            self.send_response(404); self.end_headers()
    def do_PATCH(self):
        n = int(self.headers.get('content-length', '0'))
        body = self.rfile.read(n).decode('utf-8') if n else ''
        self._log(body)
        self.send_response(200); self.send_header('content-type','application/json'); self.end_headers()
        self.wfile.write(b'{\"id\":\"c_mock\",\"title\":\"mock\",\"tags\":[],\"status\":\"in_progress\"}')
    def do_GET(self):
        self._log('')
        if self.path.startswith('/api/cards/'):
            self.send_response(200); self.send_header('content-type','application/json'); self.end_headers()
            self.wfile.write(b'{\"id\":\"c_mock\",\"title\":\"mock\",\"tags\":[\"a\",\"b\"],\"status\":\"in_progress\"}')
        else:
            self.send_response(404); self.end_headers()
    def log_message(self, *a): pass

srv = http.server.ThreadingHTTPServer(('127.0.0.1', $MOCK_KANBAN_PORT), H)
threading.Thread(target=srv.serve_forever, daemon=True).start()
import time
while True: time.sleep(60)
" &
  MOCK_KANBAN_PID=$!
  for _ in $(seq 1 30); do
    curl -s "$MOCK_KANBAN_URL/" >/dev/null 2>&1 && break
    sleep 0.1
  done
  sleep 0.2
  export MOCK_KANBAN_URL MOCK_KANBAN_PID MOCK_KANBAN_LOG
}

stop_mock_kanban() {
  [ -n "${MOCK_KANBAN_PID:-}" ] && kill "$MOCK_KANBAN_PID" 2>/dev/null
  rm -rf "${MOCK_KANBAN_DIR:-/tmp/nx}"
}
