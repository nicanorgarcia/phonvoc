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
inType=$2
hlayers=4

if [[ -z $inAudio ]]; then
    echo "PhonVoc analysis: input audio path not provided!"
    exit 1;
fi
if [[ $inType == "" ]]; then
    $inType=0
fi

if [[ ! -d steps ]]; then ln -sf $KALDI_ROOT/egs/wsj/s5/steps steps; fi
if [[ ! -d utils ]]; then ln -sf $KALDI_ROOT/egs/wsj/s5/utils utils; fi

# load phonological map
if [[ ! -e lang/$lang/${phon}-map.sh ]]; then
    echo "Please create lang/$lang/${phon}-map.sh"
    exit 1
fi
source lang/$lang/${phon}-map.sh

id=$inAudio:t:r
mkdir -p $id

geOpts=(
    -r y # Restart the job if the execution host crashes
    # -b y # Pass a path, not a script, to the execution host
    -cwd # Retain working directory
    -V   # Retain environment variables
    # -S /usr/bin/python2
    -e $id/log
    -o $id/log
    # -l q1d
    -l h_vmem=4G
)

if [[ $inType -eq 0 ]]; then
	echo "Type 0"
    echo "$id $inAudio" > $id/wav.scp
    echo "$id $voice" > $id/utt2spk
    echo "$voice $id" > $id/spk2utt
else
    echo -n "" > $id/wav.temp.scp
    for f in `cat $inAudio`; do
	echo "$f:t:r $f" >> $id/wav.temp.scp
    done
    cat $id/wav.temp.scp | sort > $id/wav.scp
    cat $id/wav.scp | awk -v voice=$voice '{print $1" "voice}' > $id/utt2spk
    cat $id/utt2spk | utils/utt2spk_to_spk2utt.pl | sort > $id/spk2utt
    rm $id/wav.temp.scp
fi
# exit

echo "-- MFCC extraction for $id input --"
steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 1 --cmd "run.pl" $id $id/log $id/mfcc
steps/compute_cmvn_stats.sh $id $id/log $id/mfcc || exit 1;
# exit

echo "-- Feature extraction for $id input --"
feats="ark:copy-feats scp:$id/feats.scp ark:- |"
[ ! -r $id/cmvn.scp ] && echo "Missing $id/cmvn.scp" && exit 1;
feats="$feats apply-cmvn --norm-vars=false --utt2spk=ark:$id/utt2spk scp:$id/cmvn.scp ark:- ark:- |"
feats="$feats add-deltas --delta-order=2 ark:- ark:- |"

echo "-- Parameter extraction --"

for att in "${(@k)attMap}"; do
echo $att

	nnet-forward train/dnns/pretrain-dbn-$lang/final.feature_transform "${feats}" ark:- | \
	nnet-forward train/dnns/${lang}-${phon}/${att}-${hlayers}l-dnn/final.nnet ark:- ark:- | \
	select-feats 1 ark:- ark:$id/${att}.ark

done


for att in "${(@k)attMap}"; do
	atts+=( ark:$id/${att}.ark )
done
paste-feats $atts ark,scp:$id/phonological.ark,$id/phonological.scp
cp $id/phnlfeats.scp $id/feats.scp

