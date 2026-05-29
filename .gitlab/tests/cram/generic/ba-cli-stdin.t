Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that one-shot positional ba-cli commands do not consume inherited stdin:

  $ R " \
  > rm -f /tmp/test-ba-cli-stdin.out; \
  > printf '%s\n' 'BA_CLI_STDIN_SENTINEL' | ba-cli -- help > /tmp/test-ba-cli-stdin.out 2>&1; \
  > if grep -q 'BA_CLI_STDIN_SENTINEL' /tmp/test-ba-cli-stdin.out; then \
  >     echo stdin-consumed; \
  > else \
  >     echo stdin-preserved; \
  > fi \
  > " </dev/null
  stdin-preserved

Check that one-shot positional ba-cli commands do not wait for open stdin:

  $ R " \
  > rm -f /tmp/test-ba-cli-open-stdin.fifo /tmp/test-ba-cli-open-stdin.out /tmp/test-ba-cli-open-stdin.rc; \
  > mkfifo /tmp/test-ba-cli-open-stdin.fifo; \
  > (sleep 5 > /tmp/test-ba-cli-open-stdin.fifo) & writer=\$!; \
  > (ba-cli -- help < /tmp/test-ba-cli-open-stdin.fifo > /tmp/test-ba-cli-open-stdin.out 2>&1; echo \$? > /tmp/test-ba-cli-open-stdin.rc) & cli=\$!; \
  > for _ in 1 2 3; do [ -s /tmp/test-ba-cli-open-stdin.rc ] && break; sleep 1; done; \
  > if [ ! -s /tmp/test-ba-cli-open-stdin.rc ]; then \
  >     kill \$cli 2>/dev/null || true; \
  >     echo positional-hung; \
  > else \
  >     echo positional-exited; \
  > fi; \
  > kill \$writer 2>/dev/null || true; \
  > rm -f /tmp/test-ba-cli-open-stdin.fifo /tmp/test-ba-cli-open-stdin.rc \
  > " </dev/null
  positional-exited

Check that explicit automated stdin-script mode still reads stdin:

  $ R " \
  > rm -f /tmp/test-ba-cli-automated-stdin.out /tmp/test-ba-cli-automated-stdin.rc; \
  > (printf '%s\n' '!amx exit' | ba-cli -a > /tmp/test-ba-cli-automated-stdin.out 2>&1; echo \$? > /tmp/test-ba-cli-automated-stdin.rc) & cli=\$!; \
  > for _ in 1 2 3; do [ -s /tmp/test-ba-cli-automated-stdin.rc ] && break; sleep 1; done; \
  > if [ ! -s /tmp/test-ba-cli-automated-stdin.rc ]; then \
  >     kill \$cli 2>/dev/null || true; \
  >     echo automated-stdin-hung; \
  > elif [ \"\$(cat /tmp/test-ba-cli-automated-stdin.rc)\" = 0 ]; then \
  >     echo automated-stdin-exited; \
  > else \
  >     echo automated-stdin-failed; \
  > fi; \
  > rm -f /tmp/test-ba-cli-automated-stdin.rc \
  > " </dev/null
  automated-stdin-exited
