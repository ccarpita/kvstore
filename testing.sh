#!/bin/bash

# testing.sh - a test script to prevent regressions

settest () {
  ((tnum+=1))
  tname=$(printf '%03d' $tnum)
  printf 'test %3d\n' $tnum
}

dotest () {
  settest
  "$@" 1>tout.$tname 2>terr.$tname
}

scriptcmd=$(pwd)/kvstore.sh
funccmd=kvstore

TEST_ROOT=$(mktemp -d)

mkdir $TEST_ROOT/store
export KVSTORE_DIR=$TEST_ROOT/store

mkdir $TEST_ROOT/test
export TEST_DIR=$TEST_ROOT/test

builtin cd $TEST_DIR

echo stores in $KVSTORE_DIR
echo test results in $TEST_DIR

tnum=0
tname=''
for testtype in script functions
do
  if [ "$testtype" = 'script' ]
  then
    CMD=$scriptcmd
  else
    dotest $CMD load
    dotest . $CMD load
    CMD=$funccmd
  fi

  settest
  declare -F | grep kvstore 1>tout.$tname 2>terr.$tname
  dotest $CMD ls

  dotest $CMD set teststore1_$testtype key1 val1
  dotest $CMD get teststore1_$testtype key1
  dotest $CMD set teststore1_$testtype key2 val2
  dotest $CMD set teststore1_$testtype 'key3 with spaces' 'val3 with spaces'
  dotest $CMD get teststore1_$testtype 'key3 with spaces'

  dotest $CMD set teststore2_$testtype key12 val12
  dotest $CMD get teststore2_$testtype key12
  dotest $CMD set teststore2_$testtype key22 val22
  dotest $CMD set teststore2_$testtype 'key32 with spaces' 'val32 with spaces'
  dotest $CMD get teststore2_$testtype 'key32 with spaces'

  dotest $CMD ls
  dotest $CMD lsinfo

  for i in 1 2
  do
    dotest $CMD keys teststore${i}_$testtype
    dotest $CMD vals teststore${i}_$testtype
    dotest $CMD dump teststore${i}_$testtype
    dotest $CMD dump -v teststore${i}_$testtype
    dotest $CMD dump -r teststore${i}_$testtype
    dotest $CMD dump -v -r teststore${i}_$testtype
  done

  dotest $CMD rm teststore1_$testtype key1
  dotest $CMD dump -r teststore1_$testtype

  dotest $CMD mv teststore2_$testtype key12 key122
  dotest $CMD dump -r teststore2_$testtype

  dotest $CMD mv teststore2_$testtype key122 key22
  dotest $CMD dump -r teststore2_$testtype

  dotest $CMD mv -f teststore2_$testtype key122 key22
  dotest $CMD dump -r teststore2_$testtype

  dotest $CMD rm teststore2_$testtype key22
  dotest $CMD dump -r teststore2_$testtype

  dotest $CMD drop teststore1_$testtype
  dotest $CMD ls

  dotest $CMD drop teststore1_$testtype
  dotest $CMD ls
done

for i in $(seq 1 $tnum)
do
  id=$(printf '%03d' $i)
  for j in tout terr
  do
    file=$j.$id
    [ -s $file ] && echo "=== $file ===" && cat $file && echo
  done
done > testresults

master=$(dirname $scriptcmd)/testresults
echo "Comparing this test run's results against $master..."
diff testresults $master
