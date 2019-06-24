# local_global.pm module version 0.05
# (last modified 09/07/2003 -- Bano)
#
# Given one or more candidate senses of a target word, and one or more
# senses of words around the target word (called non target words),
# this module selects that sense for the target word that is
# "semantically most similar" to the senses of the other words. Senses
# are represented using the word#pos#sense format defined above, and
# each sense refers to a unique synset in WordNet. The semantic
# similarity between two senses or synsets is computed by loading a
# similarity measure (like Lesk.pm, JC.pm, Lin.pm, Resnik.pm etc), and
# the overall similarity between a single sense of the target word and
# the senses of all the non-target words is computed using either the
# local or the global algorithm.
# 
# Copyright (c) 2001-2003
#
# Satanjeev Banerjee, Carnegie Mellon University, banerjee+@cs.cmu.edu
# Ted Pedersen,       University of Minnesota Duluth, tpederse@d.umn.edu
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to 
#
#    The Free Software Foundation, Inc., 
#    59 Temple Place - Suite 330, 
#    Boston, MA 02111-1307, USA.  
#
#-----------------------------------------------------------------------------

package local_global;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(local_global_initialize local_global_destroy local_global_disambiguate local_global_getTraceString);


# initialize the trace string. this will be used only if traces are
# requested
$traceString = "";

# Function to set up the variables used by this module.
sub local_global_initialize
{
    # first get the wordnet object
    $wn = shift;
    return (2, "Must pass a WordNet::QueryData object to local_global.pm", "")
		if(!defined $wn);
    
    # get the trace level
    my $traceLevel = shift; 
    
    return (2, "Must pass an integer trace-level to local_global.pm", "")
		if(!defined $traceLevel || $traceLevel !~ /^\d+$/);
    
    # decode it!
    %traceLevelHash = decodeTraceLevel($traceLevel);

	
	# <Bano/9/7/03>---------------------------
	# get score threshold. All non target words with max score below
	# this score will be ignored.
	
	$scoreThreshold = shift;
	
	# </Bano/9/7/03>--------------------------

    # now get the string containing the name of the distance measure
    # to be loaded.
    $simMeasure = shift; 
    
    return (2, "Must pass string containing name of relatedness measure to lesk_global.pm", "")
		if (!defined $simMeasure);
    
    # remove .pm in the end if present
    $simMeasure =~ s/\.pm$//;
    $measureClass = $simMeasure; # -
    $simMeasure =~ s/::/\//g;    # - (added 03/02/2003 -- Sid)

    # now include the package and import symbols
    require "$simMeasure.pm";
    # import $simMeasure; (modified 02/02/2003 -- Sid)
    
    # the similarity measure must implement the getSimilarityValue
    # function. Check if it is implement... otherwise complain.
    #
    # return (2, "Package $simMeasure must implement and export function ${simMeasure}_getSimilarityValue")
    #   unless (defined &{"${simMeasure}_getSimilarityValue"});
    
    # see if we have been passed a file of parameters to be passed to
    # the similarity measure
    my $paramsFile = shift;
    
    # if there is a simMeasure_initialize function call it (with
    # paramsFile if there is a paramsFile)
    # if (defined &{"${simMeasure}_initialize"})
    # {
    #   my $errorCode = 0;
    #   my $errorString = "";
    #	
    #   if(defined $paramsFile)
    #   {
    #	  ($errorCode, $errorString) = &{"${simMeasure}_initialize"}($wn, $paramsFile);
    #   }
    #   else 
    #	{ 
    #	    ($errorCode, $errorString) = &{"${simMeasure}_initialize"}($wn); 
    #	}
    #	
    #	return ($errorCode, $errorString);
    #	
    # get trace string if function defined
    #   $traceString = &{"${simMeasure}_getTraceString"}()
    #	    if (defined &{"${simMeasure}_getTraceString"});
    # }
    #
    # (modified 02/03/2003 -- Sid)
    
    my $errorCode = 0;
    my $errorString = "";
    
    if(defined $paramsFile)
    {
		$measure = $measureClass->new($wn, $paramsFile);
		if($measure) { ($errorCode, $errorString) = $measure->getError(); }
		else { return (2, "Unable to create $measureClass object.", "") }
    }
    else 
    { 
		$measure = $measureClass->new($wn);
		if($measure) { ($errorCode, $errorString) = $measure->getError(); }
		else { return (2, "Unable to create $measureClass object.", "") }
    }
	
    # get the parts of speech considered by the measure.
    my $pSpeech = "";
    $pSpeech .= "n" if($measure->{'n'});
    $pSpeech .= "v" if($measure->{'v'});
    $pSpeech .= "a" if($measure->{'a'});
    $pSpeech .= "r" if($measure->{'r'});
	
    # get trace string if function defined
    $traceString = $measure->getTraceString();

    # (Added 07/30/2003 -- Sid)
    # Internally set the traces 'on' within the measure.
    # Overrides the option in a config file.
    $measure->{'trace'} = 1;
    
    return ($errorCode, $errorString, $pSpeech);
}

# function to return the current trace string
sub local_global_getTraceString
{
    my $returnString = $traceString;
    $traceString = "";
    return($returnString);
}

# now for the main disambiguation function! 
#
#
# parameters to send to the function: 
#
# array[0]    = disambiguation strategy 
#          	0 = global
#          	1 = local
# array[1]    = size of context window
# array[2]    = index of target word in context window
# array[3]    = the context in one big string.
# array[4]    = double dimensioned array of candidate senses 
#
# parameters returned by the function:
# 
# a hash in which keys are senses and values are scores. all senses
# will have scores reported for them, even if the score is 0

sub local_global_disambiguate
{
    # get the input parameters 
    ($modeOfDisambiguation, $sizeOfContextWindow, $indexOfTargetWord, $theContext, @candidateSenses) = @_;
    
    # set up the output hash
    %senseScores = ();
    
    # clean up theContext
    $theContext = cleanContext($theContext);
    
    # reinitialize the trace string
    $traceString = "";
    
    # set up the sense data structure
    @words = ();
	@wordsWeigths = ();
    @sensesForWord = ();
    @numSensesPerWord = ();
    
    my $i = 0;
    for ($i = 0; $i < $sizeOfContextWindow; $i++)
    {
		# get the word
		$words[$i] = $candidateSenses[$i][0];
		
		if ($i < $indexOfTargetWord) {
			$wordsWeigths[$i]=($i+1)/$indexOfTargetWord;
		} elsif ($i > $indexOfTargetWord) {
			$wordsWeigths[$i]=($sizeOfContextWindow-$i)/($sizeOfContextWindow-1-$indexOfTargetWord);
	  	} else {
			$wordsWeigths[$i]=0;
		}
		
		# get the senses into sensesForWord and the number of senses
		# for this word into numSensesPerword
		my $j = 1;
		while (defined $candidateSenses[$i][$j])
		{
			$sensesForWord[$i][$j-1] = $candidateSenses[$i][$j];
			$j++;
		}
		$numSensesPerWord[$i] = $j - 1;
    }
    
    # check if we need to output the context window in the trace
	$traceString .= "Target: $indexOfTargetWord ";
	$traceString .= "Weigths [@wordsWeigths] ";
	$traceString .= "Context: @words\n" if (defined $traceLevelHash{1} && $traceLevelHash{1});
    
    # use the requested disambiguation strategy to get things going
    # and listen for error codes and error strings
    my $errorCode = 0;
    my $errorString = "";
    
    if ($modeOfDisambiguation) { ($errorCode, $errorString) = localMatching(); }
    else { ($errorCode, $errorString) = globalMatching(); } 
    
    # that gives us the senseScore hash. return it!
    return($errorCode, $errorString, %senseScores);
}

# this function disambiguates using the "local matching" mechanism. at
# the end of this function, the global hash %senseScores will have one
# score for each of the senses of the target word.
sub localMatching
{
    # for each sense of the target word we will get a score. we'll put
    # the score in the senseScores hash
    
    # we may have to receive traces from the similarity measure for
    # all the senses. So create the trace hash to get all that.
    my %simTraceHash = ();
    
    # now iterate over all the senses of the target word
    for ($i = 0; $i < $numSensesPerWord[$indexOfTargetWord]; $i++)
    {
		$senseScores{$sensesForWord[$indexOfTargetWord][$i]} = 0;
		$simTraceHash{$sensesForWord[$indexOfTargetWord][$i]} = "";
		
		# go through all the senses of all the non-target words. 
		my $j = 0;
		for (; $j <= $#words; $j++)
		{
			next if ($j == $indexOfTargetWord);
			
			# <Bano/8/30/03>---------------------------
			# Will take only the maximum of the scores from all the
			# senses of a given non-target word
			
			# ********** ORTALAMASINI DA ALABÝLRÝZ

			my %nonTargetScoresTraces = ();

			# </Bano/8/30/03>--------------------------

			my $k = 0;
			for (; $k < $numSensesPerWord[$j]; $k++)
			{
				my $similarity;
				my ($errorCode, $errorString);

				# get similarity between target sense and non-target sense.
				# (modified 03/02/2003 -- Sid)
				$similarity = $measure->getRelatedness($sensesForWord[$indexOfTargetWord][$i], $sensesForWord[$j][$k]);
				($errorCode, $errorString) = $measure->getError();
				
				# if error do what needs to be done
				if ($errorCode == 1) { printf STDERR "$errorString\n"; }
				elsif ($errorCode == 2) { return ($errorCode, $errorString); }
				
				# <Bano/8/30/03>---------------------------

				# # add similarity to score for this sense.
				# $senseScores{$sensesForWord[$indexOfTargetWord][$i]} += $similarity;
				
				$nonTargetScoresTraces{$similarity} = "";

				# if two senses of the target word have the same
				# score, the one that comes later will overwrite the
				# one that comes before in this hash. But that's fine
				# - we are only interested in the scores. The trace
				# will reveal the identify of the last one if there's
				# a tie.
				
				# </Bano/8/30/03>--------------------------
				
				# get trace string if traces requested and function defined
				# (modified 07/30/2003 -- Sid)
                if (((defined $traceLevelHash{8} && $traceLevelHash{8})
                     || (defined $traceLevelHash{16} && $traceLevelHash{16})))
                {
					# $simTraceHash{$sensesForWord[$indexOfTargetWord][$i]} .= $measure->getTraceString();
                    # $simTraceHash{$sensesForWord[$indexOfTargetWord][$i]} .= "rel($sensesForWord[$indexOfTargetWord][$i], $sensesForWord[$j][$k]) = $similarity\n";
					
					# <Bano/8/30/03>---------------------------

					$nonTargetScoresTraces{$similarity} = $measure->getTraceString();
					$nonTargetScoresTraces{$similarity} .= "rel($sensesForWord[$indexOfTargetWord][$i], $sensesForWord[$j][$k]) = $similarity\n";

					# </Bano/8/30/03>--------------------------
                }
			}

			# <Bano/8/30/03>---------------------------

			# find the maximum score for this non-target word. If
			# greater than threshold, put into %senseScores and
			# %simTraceHash, otherwise ignore.

			my ($maxScore) = sort {$b <=> $a} (keys %nonTargetScoresTraces);
			next if ($maxScore <= $scoreThreshold);
			
			$senseScores{$sensesForWord[$indexOfTargetWord][$i]} += $wordsWeigths[$j] * $maxScore; # ******* EALT
			$simTraceHash{$sensesForWord[$indexOfTargetWord][$i]} .= $nonTargetScoresTraces{$maxScore};
			# </Bano/8/30/03>---------------------------

		}
    }
    
    # and we are done! decide what trace to put into tracestring
    # first get the highest scoring sense
    my ($highest) = sort {$b <=> $a} values %senseScores;
    
    # now go through all the senses in descending order of scores
    foreach (sort {$senseScores{$b} <=> $senseScores{$a}} keys %senseScores)
    {
		last if ($senseScores{$_} < $highest && 
				 !(defined $traceLevelHash{4} && $traceLevelHash{4}) && 
				 !(defined $traceLevelHash{16} && $traceLevelHash{16}));
		
		$traceString .= "Sense of Target Word: $_\n";
		
		# print score if trace level 4 is on or if trace level 2 is on
		# and this is the highest scoring sense
		$traceString .= "Score = $senseScores{$_}\n"
			if((defined $traceLevelHash{4} && $traceLevelHash{4}) ||
			   ((defined $traceLevelHash{2} && $traceLevelHash{2}) && 
				$senseScores{$_} == $highest));
		
		# print trace from similarity measure for this sense of target
		# word if trace level 4 is on or if trace level 2 is on and
		# this is the highest scoring sense
		$traceString .= "$simTraceHash{$_}\n"
			if((defined $traceLevelHash{16} && $traceLevelHash{16}) ||
			   ((defined $traceLevelHash{8} && $traceLevelHash{8}) && 
				$senseScores{$_} == $highest));
    }
    
    return(0, ""); # 0 = no error, "" = no error string.
}

sub globalMatching
{
    my $level = shift;
    if (!(defined $level)) { $level = 0; }
    
    if ($level == 0)
    {
		# initialize %combinationScores and %combinationTraces hash
		%combinationScores = ();
		%combinationTraces = ();
		
		# %senseScores will already have been initialized by
		# local_global_dismabiguate
    }
    
    if ( $level > $#words )
    {
		# at this point the @currentSenseSet array should be quite
		# ready with a set of sense. we shall score this set! 
		
		# but first create the key to store the score 
		my $key = join ("::", @currentSenseSet);
		
		# now get similarity values between every pair of senses in
		# this set
		$combinationScores{$key} = 0;
		$combinationTraces{$key} = "";
		
		my $i = 0;
		for (; $i < $#words; $i++)
		{
			my $j = $i + 1;
			for (; $j <= $#words; $j++)
			{
				my $similarity; 
				my ($errorCode, $errorString);

				# get similarity between target sense and non-target sense.
				# (modified 03/02/2003 -- Sid)
				$similarity = $measure->getRelatedness($currentSenseSet[$i], $currentSenseSet[$j]);
				($errorCode, $errorString) = $measure->getError();
				
				# if error, do what needs to be done
				if ($errorCode == 1) { printf STDERR "$errorString\n"; }
				elsif ($errorCode == 2) { return ($errorCode, $errorString); }
				
				# add similarity to score for this sense.
				$combinationScores{$key} += $similarity;
				
				# get trace string if traces requested and function defined
				# (modified 07/30/2003 -- Sid)
                if (((defined $traceLevelHash{8} && $traceLevelHash{8}) 
                     || (defined $traceLevelHash{16} && $traceLevelHash{16})))
                {
					$combinationTraces{$key} .= $measure->getTraceString();
                    $combinationTraces{$key} .= "rel($currentSenseSet[$i], $currentSenseSet[$j]) = $similarity\n";
                }
			}
		}
		
		# done computing for this combination
		
		return;
    }
    
    my $i;
    for ($i = 0; $i < $numSensesPerWord[$level]; $i++)
    {
		$currentSenseSet[$level] = $sensesForWord[$level][$i];
		globalMatching($level+1);
    }
    
    # if level 0, we are done! put into senseScores the highest
    # scoring combination for each sense.
    
    return unless ($level == 0);
    
    my $key;
    my %simTraceHash = ();
    
    foreach $key (sort {$combinationScores{$b} <=> $combinationScores{$a}} keys %combinationScores)
    {
		# get the sense set from the key
		my @senseSet = split(/::/, $key);
		
		# check if we already have a score for this sense of the
		# target word, and if so, if its greater. if so, skip to next
		# key
		next if (defined $senseScores{$senseSet[$indexOfTargetWord]} && 
				 $senseScores{$senseSet[$indexOfTargetWord]} > $combinationScores{$key});
		
		# ok so put this score in
		$senseScores{$senseSet[$indexOfTargetWord]} = $combinationScores{$key};
		if (defined $combinationTraces{$key})
		{
			$simTraceHash{$senseSet[$indexOfTargetWord]} = $combinationTraces{$key};
		}
    }
    
    # and we are done! decide what trace to put into tracestring
    # first get the highest scoring sense
    my ($highest) = sort {$b <=> $a} values %senseScores;
    
    # now go through all the senses in descending order of scores
    foreach (sort {$senseScores{$b} <=> $senseScores{$a}} keys %senseScores)
    {
		last if ($senseScores{$_} < $highest && 
				 !(defined $traceLevelHash{4} && $traceLevelHash{4}) && 
				 !(defined $traceLevelHash{16} && $traceLevelHash{16}));
		
		$traceString .= "Sense of Target Word: $_\n";
		
		# print score if trace level 4 is on or if trace level 2 is on
		# and this is the highest scoring sense
		$traceString .= "Score = $senseScores{$_}\n"
			if((defined $traceLevelHash{4} && $traceLevelHash{4}) ||
			   ((defined $traceLevelHash{2} && $traceLevelHash{2}) && 
				$senseScores{$_} == $highest));
		
		# print trace from similarity measure for this sense of target
		# word if trace level 16 is on or if trace level 8 is on and
		# this is the highest scoring sense
		$traceString .= "$simTraceHash{$_}\n"
			if((defined $traceLevelHash{16} && $traceLevelHash{16}) ||
			   ((defined $traceLevelHash{8} && $traceLevelHash{8}) && 
				$senseScores{$_} == $highest));
    }
    
    return(0, ""); # 0 = no error, "" = no error string.
}

# cleans up the context passed to it
sub cleanContext
{
    my $context = shift;
    $context =~ s/<.*?>//g; # remove all tags
    $context =~ s/\#\w//g;  # remove all #pos tags, if present
    $context =~ s/_/ /g;    # break all compounds
    $context =~ s/\s+/ /g;  # always single space between words
    
    # stem context if required
    # $context = stem_stemString($context, 1) if ($stemmingReqd);
    # (removed 03/02/2003 -- Sid)
    
    $context =~ s/^\s*/ /;  # one space in the front
    $context =~ s/\s*$/ /;  # and one at the end
	
    return(lc($context));   # lower case it
}

# function to take a tracelevel number and to return all the various
# tracelevels being requested
sub decodeTraceLevel
{
    my $numberToDecode = shift;
    
    # start with the highest code and work your way down
    my $highestCode = 1024;
    
    while ($highestCode != 0)
    {
		if ($numberToDecode >=  $highestCode)
		{
			$numberToDecode -= $highestCode;
			$traceLevelHash{$highestCode} = 1;
		}
		else { $traceLevelHash{$highestCode} = 0; }
		
		$highestCode /= 2;
		if ($highestCode < 1) { $highestCode = 0; }
    }
    return(%traceLevelHash);
}

# this function will be called right at the end. if similarity module
# has a destroy function then that will be called.
sub local_global_destroy
{
    # (modified 02/03/2003 -- Sid)
    return 1;
}

1;
