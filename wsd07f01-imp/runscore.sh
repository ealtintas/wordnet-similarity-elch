#!/bin/bash
clear

testname="wsd4.0"
work_dir="$1/$testname"

echo "Test: $testname	Working dir: $1	Out dir: $work_dir"
mkdir $work_dir

for measure in ealt lch
do
 
 for window in 05 07 09 11 13 15
 do
 
perl wps2ans.pl -mapping wps2ans.map $work_dir/disamb-$measure-$window-$testname.wps > $work_dir/disamb-$measure-$window-$testname.ans

replace ".n" "" -- $work_dir/disamb-$measure-$window-$testname.ans

python scorer.python $work_dir/disamb-$measure-$window-$testname.ans $1/corpus.key dummy > $work_dir/score-$measure-$window-$testname.txt

 done
  
done

echo "ALL DONE!"
