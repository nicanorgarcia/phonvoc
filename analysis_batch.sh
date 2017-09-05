#!/usr/bin/zsh
# Copyright 2015 by Idiap Research Institute, http://www.idiap.ch
#
# See the file COPYING for the licence associated with this software.
#
# Author(s):
#   Milos Cernak, November 2015
#
# Modified by:
#   Nicanor Garcia, July 2017
#
# Run analysis of an input audio file
#
source Config.sh

inAudio=$1
resultsPath=$2

if [[ -z $inAudio ]]; then
    echo "PhonVoc analysis: input audio path not provided!"
    exit 1;
fi

if [[ -z $resultsPath ]]; then
    echo "PhonVoc analysis: output path not provided!"
    exit 1;
fi


if [[ ! -d $resultsPath ]]; then
	mkdir -p $resultsPath
fi

for f in $inAudio/*.wav; do
	echo "Processing $f"
	analysis.sh $f $resultsPath
done
