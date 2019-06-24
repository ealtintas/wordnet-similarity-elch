#!/usr/local/bin/perl -w

# wps2sk-answers.pl 
# Program to convert SENSEVAL answer files with answers in the
# word#pos#sense format to mnemonics using the word#pos#sense -
# mnemonic mapping output by program wps2sk.pl program by the same author.
# 
# Copyright (C) 2002
# Satanjeev Banerjee, University of Minnesota, Duluth
# bane0025@d.umn.edu
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
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#-----------------------------------------------------------------------------
#                              Start of program
#-----------------------------------------------------------------------------

# we have to use commandline options, so use the necessary package!
use Getopt::Long;

# first check if no commandline options have been provided... in which case
# print out the usage notes!
if ( $#ARGV == -1 )
{
    &minimalUsageNotes();
    exit;
}

# now get the options!
GetOptions("help", "mapping=s");

# if help has been requested, print out help!
if ( defined $opt_help )
{
    $opt_help = 1;
    showHelp();
    exit;
}

# get the filename of the mapping file
my $mapfilename = (defined $opt_mapping) ? $opt_mapping : "./mapping.txt";

# open the mapping file and read in the mapping file into a hash
open (MAP, "$mapfilename") || die "Could'nt open $mapfilename.\n";

while (<MAP>)
{
    /(\S+) (\S+)/;
    $mapHash{$1} = $2;
}

# now read in the input answer file and do all the changes etc. 

while (<>)
{
    chomp;

    # get the index part and the answer part
    /^(\S+\s+\S+)\s+(.*)\s*/;

    # print the index
    print "$1 ";

    # get the individual answers
    my @answers = split (/\s+/, $2);

    # convert answers
    my $ans;
    foreach $ans (@answers)
    {
	if (defined $mapHash{$ans}) { print "$mapHash{$ans} "; }
	else { print STDERR "Couldnt find mapping for $ans\n"; }
    }
    print "\n";
}



# function to output a minimal usage note when the user has not provided any
# commandline options
sub minimalUsageNotes
{
    print STDERR "Usage: wps2sk-answers.pl [--help | --mapping <PATH>] <FILE>\n";
    askHelp();
}

# function to output help messages for this program
sub showHelp
{
    print "Usage: wps2sk-answers.pl [--help | --mapping <FILE>]\n\n";

    print "Program to convert SENSEVAL answer files with answers in the\n";
    print "word#pos#sense format to mnemonics. Uses the word#pos#sense to\n";
    print "mnemonic mapping output by program wps2sk.pl by the same author\n\n";

    print "OPTIONS:\n\n";

    print "  --mapping FILE     Provide the file containing the mapping from\n";
    print "                     word#pos#sense strings to WordNet sensekey.s\n";
    print "                     By default \"./mapping.txt\" is assumed.\n\n";

    print "  --help             Prints this help message.\n\n";
}

# function to output "ask for help" message when the user's goofed up!
sub askHelp
{
    print STDERR "Type wps2sk-answers.pl --help for help.\n";
}

