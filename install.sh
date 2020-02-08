#! /bin/bash

# get ram size
ram=$(free --si | grep Mem | awk -F " " {'print $2'})
echo $ram