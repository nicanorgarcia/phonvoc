#!/usr/bin/zsh
# Copyright 2015 by Idiap Research Institute, http://www.idiap.ch
#
# See the file COPYING for the licence associated with this software.
#
# Author(s):
#   Milos Cernak, November 2015
#
# Run analysis of an input audio file
#
source Config.sh

inAudio=$1
outPath=$2
inType=$3
hlayers=4

if [[ -z $inAudio ]]; then
    echo "PhonVoc analysis: input audio not provided!"
    exit 1;
fi
if [[ $inType == "" ]]; then
    inType=0
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
mkdir -p $outPath$id

geOpts=(
    -r y # Restart the job if the execution host crashes
    # -b y # Pass a path, not a script, to the execution host
    -cwd # Retain working directory
    -V   # Retain environment variables
    # -S /usr/bin/python2
    -e $outPath$id/log
    -o $outPath$id/log
    # -l q1d
    -l h_vmem=4G
)

if [[ $inType -eq 0 ]]; then
	echo "Type 0"
    echo "$id $inAudio" > $outPath$id/wav.scp
    echo "$id $voice" > $outPath$id/utt2spk
    echo "$voice $id" > $outPath$id/spk2utt
else
    echo -n "" > $outPath$id/wav.temp.scp
    for f in `cat $inAudio`; do
		echo "$f:t:r $f" >> $outPath$id/wav.temp.scp
    done
    cat $outPath$id/wav.temp.scp | sort > $outPath$id/wav.scp
    cat $outPath$id/wav.scp | awk -v voice=$voice '{print $1" "voice}' > $outPath$id/utt2spk
    cat $outPath$id/utt2spk | utils/utt2spk_to_spk2utt.pl | sort > $outPath$id/spk2utt
    rm $outPath$id/wav.temp.scp
fi
# exit

echo "-- MFCC extraction for $id input --"
steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 1 --cmd "run.pl" $outPath$id $outPath$id/log $outPath$id/mfcc
steps/compute_cmvn_stats.sh $outPath$id $outPath$id/log $outPath$id/mfcc || exit 1;
# exit

echo "-- Feature extraction for $id input --"
feats="ark:copy-feats scp:$outPath$id/feats.scp ark:- |"
[ ! -r $outPath$id/cmvn.scp ] && echo "Missing $outPath$id/cmvn.scp" && exit 1;
feats="$feats apply-cmvn --norm-vars=false --utt2spk=ark:$outPath$id/utt2spk scp:$outPath$id/cmvn.scp ark:- ark:- |"
feats="$feats add-deltas --delta-order=2 ark:- ark:- |"

echo "-- Parameter extraction for paramType $paramType --"
if [[ $paramType -eq 0 || $paramType -eq 2 ]]; then
	if [[ $USE_SGE == 1 ]]; then
qsub $geOpts << EOF        
    	nnet-forward train/dnns/pretrain-dbn-$lang/final.feature_transform "${feats}" ark:- | \
	    nnet-forward train/dnns/${lang}-${phon}/phone-${hlayers}l-dnn/final.nnet ark:- ark,scp:$outPath$id/phone.ark,$outPath$id/phone.scp
EOF
	else
		nnet-forward train/dnns/pretrain-dbn-$lang/final.feature_transform "${feats}" ark:- | \
	    nnet-forward train/dnns/${lang}-${phon}/phone-${hlayers}l-dnn/final.nnet ark:- ark,scp:$outPath$id/phone.ark,$outPath$id/phone.scp
	fi
fi
if [[ $paramType -eq 1 || $paramType -eq 2 ]]; then
    for att in "${(@k)attMap}"; do
		echo $att
		if [[ $USE_SGE == 1 ]]; then
qsub $geOpts << EOF        
			nnet-forward train/dnns/pretrain-dbn-$lang/final.feature_transform "${feats}" ark:- | \
		    nnet-forward train/dnns/${lang}-${phon}/${att}-${hlayers}l-dnn/final.nnet ark:- ark:- | \
		    select-feats 1 ark:- ark:$outPath$id/${att}.ark
EOF
		else
			nnet-forward train/dnns/pretrain-dbn-$lang/final.feature_transform "${feats}" ark:- | \
			nnet-forward train/dnns/${lang}-${phon}/${att}-${hlayers}l-dnn/final.nnet ark:- ark:- | \
			select-feats 1 ark:- ark:$outPath$id/${att}.ark
		fi
		done
fi

if [[ $USE_SGE == 1 ]]; then
    while true; do
	sleep 10
	njobs=`qstat | grep STDIN | wc -l`
	echo "$njobs detectors running"
	if [[ $njobs ==  0 ]]; then
	    break
	fi
    done
fi

if [[ $paramType -eq 0 ]]; then
    cp $outPath$id/phone.scp $outPath$id/feats.scp
else
    for att in "${(@k)attMap}"; do
    	atts+=( ark:$outPath$id/${att}.ark )
    done
    paste-feats $atts ark,scp:$outPath$id/paramType1.ark,$outPath$id/phnlfeats.scp
    cp $outPath$id/phnlfeats.scp $outPath$id/feats.scp

    if [[ $paramType -eq 2 ]]; then
	paste-feats scp:$outPath$id/phnlfeats.scp scp:$outPath$id/phone.scp ark,scp:$outPath$id/paramType2.ark,$outPath$id/feats.scp
    fi
fi

exit
# TO BINARY
# count phonological classes
c=0
for att in "${(@k)attMap}"; do
    (( c = c + 1 ))
    echo $att $c
done
(( ce = c + 1 ))
cp $outPath$id/feats.scp $outPath$id/feats.continuous.scp
copy-feats scp:$outPath$id/feats.continuous.scp ark,t:- | \
    awk -v PHC=$c -v PHCE=$ce '{if (NF>2) {for(i=1; i<=PHC; i++) {printf "%1.0f ", $i} if ($PHCE != "") print $PHCE; else printf "\n"} else print $0}' | \
    copy-feats ark,t:- ark,scp:$outPath$id/feats.binary.ark,$outPath$id/feats.binary.scp
