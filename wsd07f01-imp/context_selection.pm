# context_selection.pm module version 0.4
#
# Given a context of words and a target word (to be dismabiguated), this
# module's primary purpose is to return a set of possible word senses 
# of all the words in the context.
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

package context_selection;

require Exporter;
@ISA = qw (Exporter);
@EXPORT = qw (context_selection_initialize 
	      context_selection_getCandidateSensesInWindow 
	      context_selection_getCandidateSensesForWord);

# Module to take a context string from svalLesk.pl, a window size and
# the lexelt and return a double dimensioned array filled with the
# senses that need to be considered for each word in the context
# window to disambiguate the target word.

my $wn; # will contain the instance of the WordNet database.

# function to set up the various variables
sub context_selection_initialize 
{ 
    $wn = shift;              # first the WordNet object.
    $windowSize = shift;      # then the window size.
    $usePosTags = shift;      # 0 = dont, 1 = do. Makes sense only
                              # when <p="??"/> tags are available in
                              # the context string or, for the target
                              # word, the lexelt has an attached pos

    $pSpeech = shift;         # Parts of speech to consider while selecting senses (added 02/03/2003 -- Sid) 
    
    %winStopHash = @_;        # if defined, this would be the window stop hash
    
    # put in the defaults, if values not provided
    $windowSize = 3 if (!(defined $windowSize));
    $usePosTags = 1 if (!(defined $usePosTags));
}


# function to actually get the senses. 
sub context_selection_getCandidateSensesInWindow
{
    my %senseHash = ();
    
    my $lexelt = shift; # lexelt may have pos appended to it if --pos was used. 
    
    # get the context string
    my $context = shift; # context 
    
    # the whole of the context is in $context. clean it up
    $context = process($context);

    # get the head word
    $context =~ /(.*)<head>(.*)<\/head>(.*)/;
    $leftString = $1;
    $headWord = $2;
    $rightString = $3;
    
    $headWord =~ s/\s//g;
    
    # if lexelt has a part of speech, attach it to headword too
    if ($lexelt =~ /\#(\w)$/)
    {
	$p = $1;
	$headWord =~ s/(\#\w)?$/\#$p/;
    }
    
    # if neither usePosTag nor lexelt has pos tag, remove tag from headword
    if (!$usePosTags && $lexelt !~ /\#\w$/)
    {
	# remove pos tag from head word if any
	$headWord =~ s/(\#\w)?$//;
    }
    
    my $temp = join " ", context_selection_getCandidateSensesForWord($headWord, $lexelt);
    $headWord =~ s/\#\w$//;
    $senseHash{0} = "$headWord " . $temp if ($temp);
    
    # that gets us the target word. Now get the context words
    $leftString =~ s/\s+/ /g;
    $leftString =~ s/^\s*//;
    $leftString =~ s/\s*$//;
    my @leftTokens = split /\s+/, $leftString;
    
    $rightString =~ s/\s+/ /g;
    $rightString =~ s/^\s*//;
    $rightString =~ s/\s*$//;
    my @rightTokens = split /\s+/, $rightString;
    
    my $i = 1;
    my $nextDirToTry = 0; # 0 for left
    my $leftIndex = 0;          
    my $rightIndex = 0;
    my $changeDir = 0;
    
    if (!(@leftTokens)) { $nextDirToTry = 1; }
    
    while ($i < $windowSize && (@leftTokens || @rightTokens))
    {
	my $word;
	my $thisWordCameFrom;
	
	if ($nextDirToTry) 
	{ 
	    $word = shift @rightTokens; 
	    $thisWordCameFrom = 1;
	    $nextDirToTry = 0 if(!@rightTokens);
	}
	else 
	{ 
	    $word = pop @leftTokens; 
	    $thisWordCameFrom = 0;
	    $nextDirToTry = 1 if(!@leftTokens);
	}
	
	$changeDir = 0;
	# check if this is a stop listed word
	my $temp = ($word =~ /(.*)\#.*/) ? $1 : $word;
	next if (defined $winStopHash{$temp});
	
	# if no usePosTags, remove pos tag from word if any
	$word =~ s/(\#\w)?$// if (!$usePosTags);
	
	$temp = join " ", context_selection_getCandidateSensesForWord($word);
	$word =~ s/\#\w$//;
	
	# if we could not find any senses, carry on
	next if (defined($temp) && $temp eq "");
	
	# put it in the hash, after appending the word to it
	if ($thisWordCameFrom)
	{
	    # implies this word came from the right
	    if ($temp)
	    {
		$senseHash{++$rightIndex} = "$word " . $temp;
		$nextDirToTry = 0 if (@leftTokens); 
	    }
	}
	else 
	{ 
	    if ($temp)
	    {
		$senseHash{--$leftIndex} = "$word " . $temp;
		$nextDirToTry = 1 if (@rightTokens); 
	    }
	}
	
	$i++;
    }
    
    # convert the sense hash to candidate sense double dimensioned array
    my @candidateSenseArray = ();
    my $positionOfTargetWord = 0; 
    my $index = 0;
    foreach (sort {$a <=> $b} keys %senseHash)
    {				#????????????????????????????
	$positionOfTargetWord = $index if ($_ == 0);	#???????????? HATA ??????????
				#????????????????????????????
	my @senses = split / /, $senseHash{$_};
	my $i = 0;
	for (; $i <= $#senses; $i++)
	{
	    $candidateSenseArray[$index][$i] = $senses[$i];
	}
	$index++;
    }
    
    return($index, $positionOfTargetWord, @candidateSenseArray);
}

# function to "process" the context string. In this process, if
# $usePosTags = 1 and a <pos="??"/> tag exists after a word, then the
# tag is removed and the word is converted to "word#p" format, where
# 'p' = {n, v, a, r}.

sub process
{
    my $context = shift;
    my $newContext = "";
    
    # get rid of leading and trailing spaces 
    $context =~ s/^\s+//;
    $context =~ s/\s+$//;
    
    # make sure each tag has at least one space to its right and left
    $context =~ s/</ </g;
    $context =~ s/>/> /g;
    
    # split on white space
    my @tokens = split '\s+', $context; 
    
    my $i = 0;
    for ($i = 0; $i <= $#tokens; $i++)
    {
	# use if <head> </head>
	if ($tokens[$i] =~ /^<(\/)?head>$/) { $newContext .= "$tokens[$i] "; next; }
	
	# ignore all other <tags> (pos tags will be handled WITH the
	# words they are attached to, as done below).
	if ($tokens[$i] =~ /^<.*>$/) { next; }
	
	# now, if a> pos tags are requested, b> a pos tag is present
	# just after this token and, c> the pos tag can be converted
	# to {n, v, a ,r}, then attach the pos with a '#' sign.
	if ($usePosTags && defined $tokens[$i+1] && $tokens[$i+1] =~ /<p=\"([^\"]*)\"\/>/)
	{
	    my $pos = $1;
	    
	    # convert from brill pos to wordnet pos
	    $pos = uc($pos);
	    
	    if    ($pos =~ /^N/) { $newContext .= "$tokens[$i]\#n "; }
	    elsif ($pos =~ /^V/) { $newContext .= "$tokens[$i]\#v "; }
	    elsif ($pos =~ /^J/) { $newContext .= "$tokens[$i]\#a "; }
	    elsif ($pos =~ /^R/) { $newContext .= "$tokens[$i]\#r "; }
	    else                 { $newContext .= "$tokens[$i] "; }
	}
	else { $newContext .= "$tokens[$i] "; }
    }
    
    return($newContext);
}

# function to take a word and then return the candidate senses for
# this word, if any
sub context_selection_getCandidateSensesForWord
{ 
    my $word = shift;
    my $validPOS = ($pSpeech) ? $pSpeech : "nvar"; 
                        # Changed from "nvar"  --> Sid, 02/03/2003
                        # to restrict senses in window.

    
    $word = lc($word); # lower case the whole word! To avoid problems
    # when the input text is not entirely lower cased.
    # Bano, 08/23/2002.
    
    # Get the true stem if any. True stem will be available only in
    # the case of the target word (in which case it will be the same
    # as the lexelt)
    my $trueStem = shift;
    $trueStem = "" if (!defined $trueStem);
    
    # Check 0: Does the word have a part-of-speech attached to it?
    my $wordPos = "";
    $wordPos = $1 if ($word =~ s/\#(\w)$//);
    
    # initialize the hash of candidate senses. We will use a hash
    # because during our algorithm we could get the same sense several
    # times and we don't want to return them just once each.
    my %candidateSenses = ();
    
    # Check 1: Is this a compound?
    if ($word =~ /_/)
    {
	# Add all senses of this compound across all parts of speech to
	# the candidate senses array. 
	
	while ($validPOS =~ /(\w)/g)
	{
	    my $pos = $1;
	    my @senses = $wn->query($word . "#$pos");
	    
	    while (@senses) 
	    { 
		my $temp = shift @senses; 
		$temp =~ s/ /_/g; 
		$candidateSenses{$temp} = 1; 
	    }
	}
	
	return(keys %candidateSenses);
    }
    
    # If not Check 1, then Check 2: Is surface form a baseform? 
    # Note: Since we want to use only the surface form, we shall not
    # use valid_forms() but query().
    else
    {
	# Check 2a: do we have a pos? if so, we'll only try with
	# that. otherwise with all possible
	if ($wordPos ne "")
	{
	    # If senses exist for this surface form with this part of speech, use them.
	    
	    my @senses = $wn->query($word . "#$wordPos");
	    while (@senses) 
	    { 
		my $temp = shift @senses; 
		$temp =~ s/ /_/g; 
		$candidateSenses{$temp} = 1; 
	    }
	}
	else 
	{
	    # Add every sense of every possible pos for this surface form.
	    while ($validPOS =~ /(\w)/g)
	    {
		my $pos = $1;
		my @senses = $wn->query($word . "#$pos");
		while (@senses) 
		{ 
		    my $temp = shift @senses; 
		    $temp =~ s/ /_/g; 
		    $candidateSenses{$temp} = 1; 
		}
	    }
	}
    }
    
    # Check 3: Do we have a true stem? (A true stem is one where we
    # know the pos too. A stem without a pos can't be used to generate
    # candidate senses!) NOTE: The assumption is that the pos attached
    # to the true stem is correct! If this is not so then no sense of
    # the true stem will get selected.
    my @trueStemsArray = ();
    
    if ($trueStem ne "" && $trueStem =~ /\#\w$/)
    {
	# Ok so we have a useable true stem. Push into stems array
	push @trueStemsArray, $trueStem;
    }
    else
    {
	# So find the various true stems of the word. Now we are no
	# longer restricting ourselves to the surface form but going
	# to the base form. So we need valid_form instead of query().
	
	# if we do have $trueStem, but don't have it pos (this is when
	# we are dealing with the target word, but don't know the pos
	# of the task) we shall use the trueStem instead of the word
	# here on
	
	$word = $trueStem if ($trueStem ne "");
	
	# Check 3a: Do we know pos of word?
	my $doneFlag = 0;
	if ($wordPos ne "") 
	{
	    # attempt to use only that pos
	    my @validForms = $wn->valid_forms($word . "#$wordPos");
	    while (@validForms)
	    { 
		my $temp = shift @validForms;
		$temp .= "#$wordPos" if ($temp !~ /\#/);
		$temp =~ s/ /_/g; 

		push @trueStemsArray, $temp;
		$doneFlag = 1;
	    }
	}
	
	if (!$doneFlag) # either we didn't know the pos, or the pos we had didn't work!
	{
	    while ($validPOS =~ /(\w)/g)
	    {
		my $pos = $1;
		my @validForms = $wn->valid_forms($word . "#$pos");
		while (@validForms)
		{ 
		    my $temp = shift @validForms;
		    $temp .= "#$pos" if ($temp !~ /\#/);
		    $temp =~ s/ /_/g; 
		    
		    push @trueStemsArray, $temp;
		}
	    }
	}
    }
    
    # so now we have some true stems. Use them to get senses
    while (@trueStemsArray)
    {
	my $stem = shift @trueStemsArray;
	my @senses = $wn->query($stem);
	while (@senses) 
	{ 
	    my $temp = shift @senses; 
	    $temp =~ s/ /_/g; 
	    $candidateSenses{$temp} = 1; 
	}
    }
    
    return(keys %candidateSenses);
}

1;
