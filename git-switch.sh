#!/bin/sh
gitswitch() {
  test -n "$1" || return $?
  git remote set-branches --add origin $1
  git fetch origin $1
  git checkout $1
}
gitswitch $1
