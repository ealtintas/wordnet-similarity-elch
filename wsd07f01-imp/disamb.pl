#!/usr/local/bin/perl -w
#
# disamb.pl version 0.05
# (Updated 09/07/2003 -- Bano)
#
# Program to disambiguate senseval 2 format data using various 
# measures of semantic relatedness of words, using the algorithm 
# detailed in Master's Thesis of Satanjeev Banerjee.
#
# Copyright (c) 2001-2003
#
# Satanjeev Banerjee, University of Minnesota, Duluth
# banerjee+@cs.cmu.edu
#
# Siddharth Patwardhan, University of Minnesota, Duluth
# patw0006@d.umn.edu
#
# Ted Pedersen, University of Minnesota, Duluth
# tpederse@d.umn.edu
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
#   The Free Software Foundation, Inc., 
#   59 Temple Place - Suite 330, 
#   Boston, MA  02111-1307, USA.
#-----------------------------------------------------------------------------

use Getopt::Long;		# we have to use commandline options, so use the necessary package!
use context_selection;		# include the context selection module
use local_global;		# include the local_global module: this is the disambiguation engine that runs the local/global schemas.
use WordNet::QueryData;		# now get hold of the wordnet package

# first check if no commandline options have been provided... in which case print out the usage notes!
if($#ARGV == -1) {
    &minimalUsageNotes();
    exit;
}

# now get the options!
GetOptions("simMeasure=s", "simMeasureParams=s", "local", "window=i", "windowStop=s", "usePosTags", "targetPos=s", "contextPos=s", "trace=s", "traceLevel=i", "minScore=f", "help", "version", "scoreThreshold=f");

# if help has been requested, print out help!
if(defined $opt_help) {
    $opt_help = 1;
    &showHelp();
    exit;
}

# if version has been requested, show version!
if(defined $opt_version) {
    $opt_version = 1;
    &showVersion();
    exit;
}

# switches --simMeasure is compulsory. Check if provided, if not, complain.
die "Compulsory switch --simMeasure not used. Aborting.\n"
    unless defined $opt_simMeasure;

# now instantiate a copy of the word net database... this will take time!
print STDERR "Loading WordNet... ";
my $wn = WordNet::QueryData->new;
print STDERR "done!\n";

# compute the trace level. If non zero, open trace file.
if(defined $opt_trace && defined $opt_traceLevel) {
    $traceLevel = $opt_traceLevel;
    open(TRACE, ">$opt_trace") || die "Couldn't open $opt_trace for writing\n";
}
else { $traceLevel = 0; }

# <Bano/9/7/03>---------------------------
# get score threshold. All non target words with max score below
# this score will be ignored.

$opt_scoreThreshold = 0 unless (defined $opt_scoreThreshold);

# </Bano/9/7/03>--------------------------

# initialize local_global, and look for error codes etc.
my $errorCode = 0;
my $errorString = "";
my $pSpeech;            # (added 02/03/2003 -- Sid)

if(defined $opt_simMeasureParams) { 
    ($errorCode, $errorString, $pSpeech) = local_global_initialize($wn, $traceLevel, $opt_scoreThreshold, $opt_simMeasure, $opt_simMeasureParams); 
}
else { 
    ($errorCode, $errorString, $pSpeech) = local_global_initialize($wn, $traceLevel, $opt_scoreThreshold, $opt_simMeasure); 
}

# (modified 02/03/2003 -- Sid)

$pSpeech = "nvar" if((defined $pSpeech && $pSpeech !~ /[nvar]/) || !defined $pSpeech);
# (added 03/25/2003 -- Sid)

if($errorCode) {
#     print STDERR "$errorString\n";
    exit if ($errorCode == 2);
}

# check for trace string
print TRACE "$traceString\n" 
    if($traceLevel && ($traceString = local_global_getTraceString()) ne "");

# check what dismabiguation strategy is called for, local or
# global. Local = 1, global = 0.
$disambStrategy = (defined $opt_local) ? $opt_local : 0;

# if switch --windowStop used, create stop hash for window
if(defined $opt_windowStop) {
    open (WIN_STOP, $opt_windowStop) || die ("Couldnt open $opt_windowStop!\n");
    
    while(<WIN_STOP>) {
	chomp;
	s/\s//g;
	$winStopHash{$_} = 1;
    }
    close WIN_STOP;
}

$windowSize = (defined $opt_window) ? $opt_window : 3;			# decide the window size default is 3

my $posTagFlag = (defined $opt_usePosTags) ? $opt_usePosTags : 0;	# decide whether pos tags are required

# If the user has dedcided that the neighboring words can only be of a particular part of speech. (added 06/11/2003 -- Sid)
if(defined $opt_contextPos && $opt_contextPos =~ /[nvar]/) {
    my $lo = "";
    my $lpos;

    foreach $lpos ("n", "v", "a",  "r")
    {
	$lo .= $lpos if($pSpeech =~ /$lpos/ && $opt_contextPos =~ /$lpos/);
    }
    if($lo eq "")
    {
	print STDERR "Warning: This context part-of-speech restriction cannot be handled by relatedness module.\n";
	print STDERR "Ignoring '--contextPos'.\n";
    }
    else
    {
	$pSpeech = $lo;
    }
}

# Now initialize the context_selection module with 
# a> the wordnet object,
# b> the window size, 
# c> the posTagsFlag, and 
# d> the window stop hash, if one is provided

if(defined $opt_windowStop) { context_selection_initialize($wn, $windowSize, $posTagFlag, $pSpeech, %winStopHash); }
else { context_selection_initialize($wn, $windowSize, $posTagFlag, $pSpeech); }
# (modified 02/03/2003 -- Sid)

# now the main fun: go thru the input file(s) and disambiguate!!
$insideContext = 0;
$context = "";

$opt_minScore = -1 if(!defined $opt_minScore || ($opt_minScore !~ /^\-?(([0-9]+(\.[0-9]+)?)|(\.[0-9]+))$/));
# (added 06/11/2003 -- Sid)

while($nextLine = <>) {
    if(!$insideContext) {
	if($nextLine =~ /<lexelt item=\"(.*?)\"/) {
	    $lexelt = $1;
	}
	
	if($nextLine =~ /<instance id=\"(.*?)\"/) {
	    $instanceId = $1; 
	}
	
	if($nextLine =~ /<context>/) { 
	    $insideContext = 1; 
	    $context = $nextLine; 
	}
    }
    else {
	$context .= $nextLine;
	
	if($nextLine =~ /<\/context>/) {
	    $insideContext = 0;
	    
	    # From $context remove <context> and anything before it. Similarly, remove </context> and everything after
	    # it. What will remain are the context sentences. 
	    
	    $context =~ s/.*<context>//;
	    $context =~ s/<\/context>.*//;
	    
	    # Now to give the lexelt and the context string to the context_selection_getCandidateSensesInWindow()
	    # function. This returns a> the size of the window being returned, b> the index of the target word, and c> a
	    # double dimensioned array containing all the candidate senses for all the words in the context window.
	    
	    my $sizeOfWindow = 0; 
	    
            # $sizeOfWindow will contain the actual size of the window formed by context_selection.pm. Usually, this would be
            # the same as $windowSize, except when not enough words were found in the $context string to put into the window.
	    
	    my $targetWordPosition = 0;
	    
	    # This will contain the position of the targetWord in the window. This will be as close to the centre as possible.
	    
	    my @senses = (); 
	    
	    # Array @senses will be a double dimensioned array with as many rows as there are words in the context
	    # window. $senses[$i][0] will contain the actual surface form (with an attached pos if present) that was
	    # selected. $senses[$i][1...] will contain the actual senses to be considered. Senses are in the form
	    # word#pos#sense.$lexelt = $1;
	    
	    # Now call the function! But first 'fix' the lexelt
	    $tempLexelt = $lexelt;
	    
	    # remove everything after '.'
	    # $tempLexelt =~ s/\..*//;

	    ## tdp nov 14, 2003, change to fix handling of embedded 
	    ## periods in lexelts. Previously it was assumed that
            ## there would only be one period in a lexelt, that being
	    ## the one before the pos indicating (e.g., art.n grip.n)
	    ## however, this causes a problem with lexelts such as
            ## u.s., which are treated as u. in addition to u.s.

	      $tempLexelt =~ s/\..$//;
	    
	    # attach the part of speech to the lexelt, if given
	    $tempLexelt .= "\#$opt_targetPos" if (defined $opt_targetPos);
	    
	    ($sizeOfWindow, $targetWordPosition, @senses) = 
		context_selection_getCandidateSensesInWindow($tempLexelt, $context);
	    
	    # this gives us the candidate senses. Send to
	    # local_global_disambiguate function to disambiguate.  
	    # This function returns a hash with keys as senses and 
	    # values as scores.
	    
	    $errorCode = 0;
	    $errorString = "";
	    
	    my %senseScores = ();
	    
	    ($errorCode, $errorString, %senseScores) = 
		local_global_disambiguate($disambStrategy, $sizeOfWindow, $targetWordPosition, $context, @senses);
	    
	    if($errorCode)
	    {
 		print STDERR "$errorString *** \n";
		exit if ($errorCode == 2);
	    }
	    
            # check for trace string
	    if($traceLevel && ($traceString = local_global_getTraceString()) ne "")
	    {
		print TRACE "\n$lexelt $instanceId\n\n";
		print TRACE "$traceString\n";
	    }
	    
	    # now print out all senses tied at the highest score.
	    my $atLeastOnePrinted = 0;
	    my ($highestScore) = sort {$b <=> $a} values %senseScores;
	    
	    # (modified 06/11/2003 -- Sid)
	    if($highestScore > $opt_minScore)
	    {
		foreach(sort {$senseScores{$b} <=> $senseScores{$a}} keys %senseScores)
		{
		    # quit loop if below minimum score cutoff
		    last if($senseScores{$_} < $highestScore);
		    
		    # right, so print the heading if not already printed
		    print "$lexelt $instanceId " if(!$atLeastOnePrinted);
		    
		    # and print the sense!
		    print "$_ ";
		    
		    # so we've printed at least one!
		    $atLeastOnePrinted = 1;
		}
	    }
	    
	    print "\n" if($atLeastOnePrinted);
	    
	    # done with this instance. go on to the next one!
	    $context = "";
	    next;
	}
    }
}

close TRACE;

# call the local_global_destroy function so that it can do whatever
# clean-up it needs to
local_global_destroy();

# End of program!!

# function to output a minimal usage note when the user has not provided any
# commandline options
sub minimalUsageNotes
{
    print "Usage: disamb.pl [[OPTIONS] --simMeasure <module> <xml data file>]\n";
    askHelp();
}

# function to output help messages for this program
sub showHelp
{
    print "Usage: disamb.pl [[OPTIONS] --simMeasure <module> <xml data file>]\n\n";
    
    print "Disambiguates lexical elements in a Senseval 2 format <xml data file>\n";
    print "using the given similarity measure contained in a Perl module <module>\n";
    print "and using algorithms described in Masters' Thesis, Satanjeev Banerjee,\n";
    print "2002, University of Minnesota Duluth.\n\n";
    
    print "OPTIONS:\n\n";
    
    print "  --simMeasure <module>\n";
    print "                     This switch specifies which similarity measure to use\n";
    print "                     to perform the disambiguation with. <module> must be a\n";
    print "                     Perl module that measures the relatedness of word senses.\n";
    print "                     This package was created based on the WordNet::Similarity\n";
    print "                     modules, but any module following that format can be used.\n\n";
    
    print "  --simMeasureParams FILE\n";
    print "                     This switch allows the user to set and pass parameters\n";
    print "                     to the similarity measure. FILE is passed to the measure\n";
    print "                     during its initialization. It is the responsibility of the\n";
    print "                     measure to open and parse this file.\n\n";
    
    print "  --local            This switch specifies that the \"local\" disambiguation\n";
    print "                     strategy should be followed while disambiguating the\n";
    print "                     target word. By default, the \"global\" approach is\n";
    print "                     used.\n\n";
    
    print "  --window N         Sets window size to N. This is used to create the\n";
    print "                     context window. A window of N words is created, with the\n";
    print "                     target word as close to the centre as possible.\n\n";
    
    print "  --windowStop FILE  Words in FILE are ignored when creating the context\n";
    print "                     window around the target word.\n\n";
    
    print "  --usePosTags       This switch allows disamb.pl to use the part-of-speech\n";
    print "                     tags associated with the non-target words (if present) to\n";
    print "                     restrict the disambiguation process to only those senses\n";
    print "                     that are appropriate for those parts-of-speech. By\n";
    print "                     default, these tags are ignored if present.\n\n";
    
    print "  --targetPos P      Specifies the part-of-speech of the target word. This\n";
    print "                     overrides the target word's part-of-speech tag if present.\n";
    print "                     P should be either 'n' (noun), 'v' (verb), 'r' (adverb)\n";
    print "                     or 'a' (adjective)\n\n";
    
    print "  --contextPos S     Specifies the part-of-speech of the context words. This\n";
    print "                     causes the algorithm to consider only those senses of the\n";
    print "                     context words that occur in the specified part-of-speech.\n";
    print "                     S can be either 'n' (noun), 'v' (verb), 'a' (adjective)\n";
    print "                     or 'r' (adverb).\n\n";

    print "  --trace FILE       Sends to FILE trace information from the disambiguation.\n\n";
    
    print "  --traceLevel N     This sets the level of debug information to be output\n";
    print "                     if switch --trace is used. See README for trace level\n";
    print "                     codes and how to use them. If not used, no traces are\n";
    print "                     output even if --trace above is used.\n\n";

    print "  --minScore SCORE   The score of relatedness with the context, of any sense\n";
    print "                     of the target word, must be at least above SCORE for that\n";
    print "                     sense to be even considered a candidate for the answer.\n\n";
    
	print "  --scoreThreshold SCORE\n";
	print "                     For given sense of target word, ignore the score from a\n";
	print "                     particular non-target word if it is <= SCORE. Default = 0.\n\n";

    print "  --help             Prints this help message.\n\n";
    
    print "  --version          Prints the version number.\n\n";
}

# function to output the version number
sub showVersion
{
    print "disamb.pl version 0.42\n";
    print "Copyright (c) 2001-2003, Satanjeev Banerjee, Siddharth Patwardhan & Ted Pedersen\n";
}

# function to output "ask for help" message when the user's goofed up!
sub askHelp
{
    print STDERR "Type disamb.pl --help for help.\n";
}
