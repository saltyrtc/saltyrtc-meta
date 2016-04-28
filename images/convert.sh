#!/bin/bash
for f in *.svg; do
    convert $f $f.png
done
