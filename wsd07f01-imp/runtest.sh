#!/bin/bash
clear

testname="$2"
work_dir="$1/$testname"

echo "Output: $work_dir"
mkdir $work_dir

# for window in 03 05 07 09 11 15 17 19 21 23 25 27 31 33 35 37 39 41 43 45 47 49
for window in 03
 do
 
 for measure in lch
 do


echo "Disamb::$measure Window:$window"

echo " *** TIME_LOG $measure.$window	" >> $work_dir/time.log 

time --append -o $work_dir/time.log perl disamb.pl --simMeasure WordNet::Similarity::$measure --local --targetPos n --contextPos n --window $window --windowStop disamb.stoplist --traceLevel 3 --trace $work_dir/trace-$measure-$window-$testname.txt $1/corpus.xml > $work_dir/disamb-$measure-$window-$testname.wps

perl wps2ans.pl -mapping wps2ans.map $work_dir/disamb-$measure-$window-$testname.wps > $work_dir/disamb-$measure-$window-$testname.ans

replace ".n" "" -- $work_dir/disamb-$measure-$window-$testname.ans

python scorer.python $work_dir/disamb-$measure-$window-$testname.ans $1/corpus.key dummy > $work_dir/score-$measure-$window-$testname.txt


 done
 
 echo "Window $window done."
 
done

echo "done!"