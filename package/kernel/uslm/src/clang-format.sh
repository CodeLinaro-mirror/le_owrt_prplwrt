#!/bin/sh
CLANG_FORMAT="clang-format"
if ! [ -x "$(command -v ${CLANG_FORMAT})" ]; then
    echo "'${CLANG_FORMAT}' not found. Bye!"
    exit 1
fi

git ls-files -- '*.c' '*.h' | xargs clang-format -i -style=file