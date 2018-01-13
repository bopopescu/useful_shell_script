#!/bin/sh
if [ ! $# -eq 2 ]
  then
    echo "Two arguments needed!"
    exit
fi

grep -rI $1 *|awk '{split($1, c,":");print c[1];}'|xargs sed -i "s/$1/$2/g" 
