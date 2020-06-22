#!/bin/bash

# SPIKE: nohop study
# forking bg processes via nohup 
export DIR=$PWD
echo "main start"

export OUT5_LOG=${OUT5_LOG:-$DIR/nohup-out5.log}

nohup bash <<EOS  &> $OUT5_LOG &
date
echo 'sleep 5...'
sleep 5
date
echo 'wake up 5'
EOS
export SLEEP5_PID=$!

nohup bash <<EOS  &> nohup-out10.log &
date; 
echo 'sleep 10...'; 
sleep 10;  
date
EOS
export SLEEP10_PID=$!

echo "sleep 5: $SLEEP5_PID"
echo "sleep 10: $SLEEP10_PID"

wait $SLEEP5_PID
date
echo "sleep5 finished"

wait
date
echo "main: finish"
