#!/bin/sh

d="alt"

if [ "${1:-}" = "clean" ]; then
  rm -f $d/umkaos-r???[0-9]
  exit 0
fi

set -e
for r in $(seq 0 9); do
  n=0;
  for a in "___a" FNCS; do
    for b in "___b" MTBL MLTB; do
      for c in "_______c" RNG_ONLY; do
        for o in s $(seq 0 3); do
          for p in "pie   " "no-pie"; do
            for f in "lto   " "no-lto"; do
              n=$((n+1))
              exe=$(printf "umkaos-r%d%03d" $r $n)
              flg="-D_USE_$a -D_USE_$b -D_$c -O$o -$p -f$f"
              cmd="cc \$CFLAGS -o $d/$exe -I. -I../usrl $d/umkaos-r$r.c"
              echo "$cmd $flg"
              eval "$cmd $flg" 2>/dev/null
              if ! echo "$flg" | grep -q "RNG_ONLY"; then
                $d/$exe > uchaos_tbl.h
                eval "$cmd $flg -D_RNG_ONLY" 2>/dev/null
              fi
              nc=$($d/$exe | wc -lc | tr -d ' ')
              nl=$($d/$exe | grep -E "robang74|umkaos|dataout" | wc -l)
              if [ "$nl$nc" != "37123" ]; then ./umkaos; exit 1; fi
            done
          done
        done
      done
    done
  done
done

