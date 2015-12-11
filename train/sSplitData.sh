#!/usr/bin/zsh
#
# Copyright 2015 by Idiap Research Institute, http://www.idiap.ch
# See the file COPYING for the licence associated with this software.
#
# Split data to the dev and test sets
#
# Milos Cernak, November 2015
#
source ../Config.sh

data=../lang/$lang/data/$voice
inDevDir=$data/idev
inTestDir=$data/itest
inTrainDir=$data/itrain

outDevDir=$data/odev
outTestDir=$data/otest
outTrainDir=$data/otrain

ifeatdir=feats/in-${lang}-${phon}-${voice}
ofeatdir=feats/out-${lang}-${phon}-${voice}-$vocod

if [[ $voice == "Nancy" ]]; then
    trainSplit=10000
    # the train set: <1,trainSplit>
    devSplit=1000
    (( testSplit = trainSplit + devSplit ))
    # the dev set: <trainSplit+1,testSplit>
    # the test set: <testSplit+1,rest>
    # remove leading and trailing silences, constant 15 frames
    # echo "Cutting leading trailing silence"
    # feat-to-len scp:$ifeatdir/feats.scp ark,t:- | \
    # 	awk '{print $1" "$1" 15 "$2-15}' > $ifeatdir/segments.txt
    # extract-rows $ifeatdir/segments.txt scp:$ifeatdir/feats.scp ark,scp:$ifeatdir/cutfeats.ark,$ifeatdir/cutfeats.scp
    # extract-rows $ifeatdir/segments.txt scp:$ofeatdir/feats.scp ark,scp:$ofeatdir/cutfeats.ark,$ofeatdir/cutfeats.scp
fi

# normalize input features: create spk2utt and call 

# split input
mkdir -p $inTrainDir $inDevDir $inTestDir

# itrain
cat $ifeatdir/feats.scp | head -n $trainSplit > $inTrainDir/feats.scp
cp $ifeatdir/cmvn.scp $inTrainDir
echo -n "nan" > $inTrainDir/spk2utt
cat $inTrainDir/feats.scp | awk '{ printf " %s", $1}END{print ""}' >> $inTrainDir/spk2utt
utils/spk2utt_to_utt2spk.pl $inTrainDir/spk2utt > $inTrainDir/utt2spk

# idev
(( itrainSplit = trainSplit + 1 ))
cat $ifeatdir/feats.scp | tail -n +$itrainSplit | head -n $devSplit > $inDevDir/feats.scp
cp $ifeatdir/cmvn.scp $inDevDir
echo -n "nan" > $inDevDir/spk2utt
cat $inDevDir/feats.scp | awk '{ printf " %s", $1}END{print ""}' >> $inDevDir/spk2utt
utils/spk2utt_to_utt2spk.pl $inDevDir/spk2utt > $inDevDir/utt2spk

# itest
(( itestSplit = testSplit + 1 ))
cat $ifeatdir/feats.scp | tail -n +$itestSplit > $inTestDir/feats.scp
cp $ifeatdir/cmvn.scp $inTestDir
echo -n "nan" > $inTestDir/spk2utt
cat $inTestDir/feats.scp | awk '{ printf " %s", $1}END{print ""}' >> $inTestDir/spk2utt
utils/spk2utt_to_utt2spk.pl $inTestDir/spk2utt > $inTestDir/utt2spk

# exit
# normalise output features

mkdir -p $outTrainDir $outDevDir $outTestDir

# otrain
cat $ofeatdir/feats.scp | head -n $trainSplit > $outTrainDir/feats.scp
cp $ofeatdir/cmvn.scp $outTrainDir
echo -n "nan" > $outTrainDir/spk2utt
cat $outTrainDir/feats.scp | awk '{ printf " %s", $1}END{print ""}' >> $outTrainDir/spk2utt
utils/spk2utt_to_utt2spk.pl $outTrainDir/spk2utt > $outTrainDir/utt2spk

# odev
(( otrainSplit = trainSplit + 1 ))
cat $ofeatdir/feats.scp | tail -n +$otrainSplit | head -n $devSplit > $outDevDir/feats.scp
cp $ofeatdir/cmvn.scp $outDevDir
echo -n "nan" > $outDevDir/spk2utt
cat $outDevDir/feats.scp | awk '{ printf " %s", $1}END{print ""}' >> $outDevDir/spk2utt
utils/spk2utt_to_utt2spk.pl $outDevDir/spk2utt > $outDevDir/utt2spk

# otest
(( otestSplit = testSplit + 1 ))
cat $ofeatdir/feats.scp | tail -n +$otestSplit > $outTestDir/feats.scp
cp $ofeatdir/cmvn.scp $outTestDir
echo -n "nan" > $outTestDir/spk2utt
cat $outTestDir/feats.scp | awk '{ printf " %s", $1}END{print ""}' >> $outTestDir/spk2utt
utils/spk2utt_to_utt2spk.pl $outTestDir/spk2utt > $outTestDir/utt2spk

# pre-process original test audio for objective comparison
if [[ ! -d $data/test-audio ]]; then
    mkdir -p $data/test-audio
    for f in `cat $data/wav.scp | tail -n +$otestSplit | awk '{print $2}'`; do
	sox $f -r 8k $data/test-audio/$f:t
    done
fi