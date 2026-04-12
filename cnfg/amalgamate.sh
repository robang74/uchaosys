#!/bin/bash

set -e

mkdir -p amalgamation

CFLAGS=${CFLAGS:-}
CFLAGS_EXTRA=${CFLAGS_EXTRA:-}
OUTPUT_PREFIX=${OUTPUT_PREFIX:-_build/amalgamation}
CCPREFIX=${CCPREFIX:-}

CFLAGS="${CFLAGS}" cmake -H. -B_build -DAMALGAMATE_SOURCES=ON -G"Unix Makefiles"

if [ "${SKIPTESTS:-0}" != "1" ]; then

echo "int main() { return 0; }" > main.c
echo "Test compile with GCC..."
${CCPREFIX}gcc -pedantic -Wall -Wno-unused-function -I${OUTPUT_PREFIX} main.c ${OUTPUT_PREFIX}/miniz.c -o test.out ${CFLAGS} ${CFLAGS_EXTRA}
echo "Test compile with GCC ANSI..."
${CCPREFIX}gcc -std=gnu89 -pedantic -Wall -Wno-unused-function -I${OUTPUT_PREFIX} main.c ${OUTPUT_PREFIX}/miniz.c -o test.out ${CFLAGS} ${CFLAGS_EXTRA}
if command -v clang; then
        echo "Test compile with clang..."
        clang -Wall -Wno-unused-function -Wpedantic -fsanitize=unsigned-integer-overflow -I${OUTPUT_PREFIX} main.c ${OUTPUT_PREFIX}/miniz.c -o test.out ${CFLAGS} ${CFLAGS_EXTRA}
fi
for def in MINIZ_NO_STDIO MINIZ_NO_TIME MINIZ_NO_DEFLATE_APIS MINIZ_NO_INFLATE_APIS MINIZ_NO_ARCHIVE_APIS MINIZ_NO_ARCHIVE_WRITING_APIS MINIZ_NO_ZLIB_APIS MINIZ_NO_ZLIB_COMPATIBLE_NAMES MINIZ_NO_MALLOC
do
	echo "Test compile with GCC and define $def..."
	${CCPREFIX}gcc -std=gnu89 -pedantic -Wall -Wno-unused-function -I${OUTPUT_PREFIX} main.c ${OUTPUT_PREFIX}/miniz.c -o test.out -D${def} ${CFLAGS} ${CFLAGS_EXTRA}
done
echo "Test compile with GCC and MINIZ_USE_UNALIGNED_LOADS_AND_STORES=1..."
${CCPREFIX}gcc -std=gnu89 -pedantic -Wall -Wno-unused-function -I${OUTPUT_PREFIX} main.c ${OUTPUT_PREFIX}/miniz.c -o test.out -DMINIZ_USE_UNALIGNED_LOADS_AND_STORES=1 ${CFLAGS} ${CFLAGS_EXTRA}
rm test.out
rm main.c

fi # SKIP TESTS WHEN AREN'T USEFUL

cp ${OUTPUT_PREFIX}/miniz.* amalgamation/
cp ChangeLog.md amalgamation/
cp LICENSE amalgamation/
cp readme.md amalgamation/
mkdir -p amalgamation/examples
cp examples/* amalgamation/examples/

cd amalgamation
test ! -r miniz.zip || rm -f miniz.zip
cat << EOF | zip -@ miniz
miniz.c
miniz.h
ChangeLog.md
LICENSE
readme.md
examples/example1.c
examples/example2.c
examples/example3.c
examples/example4.c
examples/example5.c
examples/example6.c
EOF
cd ..

echo "Amalgamation created."

