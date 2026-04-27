#!/usr/bin/env bats
load helpers

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests*}"
  source "$REPO_ROOT/lib/buffer.sh"
}

@test "buffer_truncate caps to 500 chars" {
  long="$(head -c 600 < /dev/urandom | base64 | head -c 600)"
  result="$(buffer_truncate "$long" 500)"
  [ "${#result}" -le 500 ]
}

@test "buffer_redact strips TOKEN/SECRET/KEY/PASSWORD env-var values" {
  out="$(buffer_redact 'export FOO=ok BAR_TOKEN=abc123 PASSWORD=p MY_SECRET=s API_KEY=k')"
  [[ "$out" != *"abc123"* ]]
  [[ "$out" != *"=p"*  ]] || [[ "$out" =~ "PASSWORD=<redacted>" ]]
  [[ "$out" != *"=s"*  ]] || [[ "$out" =~ "SECRET=<redacted>" ]]
  [[ "$out" != *"=k"*  ]] || [[ "$out" =~ "API_KEY=<redacted>" ]]
  [[ "$out" == *"FOO=ok"* ]]
}
