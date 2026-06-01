#!/bin/sh -x

d="alt"

if [ "${1:-}" = "clean" ]; then
  rm -f $d/umkaos-r???[0-9]{,.err}
  exit 0
elif [ "${1:-}" = "tarball" ]; then
  tar czf umkaos-hurd.tgz $d/umkaos-r???[0-9]
  du  -ks umkaos-hurd.tgz
  exit $?
fi

r_seq=${1:-$(seq 0 9)}

DOCKNAME="alpine-i386-dev"
INCL=${INCL:--I. -I.. -I../usrl -I../../usrl}

if [ "${NO_DOCKER:-0}" != "1" ]; then
  test -r  getnanos.h || ln -f ../usrl/getnanos.h .
  if docker ps -a 2>&- | grep -q $DOCKNAME; then
    echo
    echo "Using docker named: $DOCKNAME"
    echo
    devc="-u $(id -u):$(id -g) -v .:/src -w /src $DOCKNAME"
    docker run --rm $devc /bin/sh -c "NO_DOCKER=1 sh $0 $1"
    exit $?
  fi
  strp() { true; }
else
  CFLAGS="-Wno-format-extra-args -fno-ident -Qn -falign-functions=32"
  CFLAGS="$CFLAGS -ffunction-sections -fdata-sections -Wl,--gc-sections -g0"
  CFLAGS="$CFLAGS -m32 -march=i486 -mtune=generic -mno-avx -mno-sse -mno-sse3"
  CFLAGS="$CFLAGS -mno-sse2 -mno-avx2 -Wl,--build-id=none -static -s"
  strp() {
    strip --strip-all --remove-section=.comment --remove-section=.note $@
  }
  sync
fi

wrtchktbl() {
  $1 | tee uchaos_tbl.h.tmp | grep -q MTBL &&
    mv -f uchaos_tbl.h.tmp uchaos_tbl.h
}

exe="umkaosh"; rm -f $exe
cc $CFLAGS $INCL umkaos.c -o $exe &&
  wrtchktbl ./$exe ||                                                     exit 2

set -e
for r in $r_seq; do
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
              cmd="cc \$CFLAGS -o $d/$exe \$INCL $d/umkaos-r$r.c"
              rm -f $d/$exe
              echo "$cmd $flg"
              eval "$cmd $flg" 2>$exe.err || {
                cat $exe.err;                                             exit 3
              }; rm -f $exe.err
              if echo "$flg" | grep -q "RNG_ONLY"; then
                strp $d/$exe
              else
                wrtchktbl $d/$exe ||                                      exit 4
                eval "$cmd $flg -D_RNG_ONLY" 2>/dev/null  ||              exit 5
              fi
              nc=$($d/$exe | wc -lc | tr -d ' ')
              nl=$($d/$exe | grep -E "robang74|umkaos|dataout" | wc -l)
              if [ "$nl$nc" != "37123" -a "$nl$nc" != "37124" ]; then
                $d/$exe; printf "\nnl:$nl/3  nc:$nc/7:123:124\n";         exit 6
              fi
            done
          done
        done
      done
    done
  done
done

