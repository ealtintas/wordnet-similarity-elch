# WordNet::Similarity::elch.pm version 0.1
# (Last update $Id: elch.pm,v 1.18 2004/12/23 07:23:04 sidz1979 Exp $)
#
# Semantic Similarity Measure package improving the measure
# described by Leacock and Chodorow (1998) using specifity values derived from the WordNet Hierarchy.

package WordNet::Similarity::elch;

use strict;

use Exporter;
use WordNet::Similarity::LCSFinder;
use WordNet::Similarity::DepthFinder;

our @ISA = qw/WordNet::Similarity::LCSFinder/;

our $VERSION = '0.01';

#
#  YOU SHOULD CAREFULLY CONSIDER THIS CONSTANTS THEY CHANGE THE SUCCESS RATE
#
our $LengthConstant = 1;
our $DepthConstant = 0.5;

sub setPosList {
  my $self = shift;
  $self->{n} = 1;
  $self->{v} = 1;
}

sub getRelatedness
{
    my $self = shift;
    my $wps1 = shift;
    my $wps2 = shift;
    my $wn = $self->{wn};

    my $class = ref $self || $self;

    unless ($wn) {
	$self->{errorString} .= "\nError (${class}::getRelatedness()) - ";
	$self->{errorString} .= "A WordNet::QueryData object is required.";
	$self->{error} = 2;
	return undef;
    }

    # Initialize traces.
    $self->{traceString} = "";

    my $ret = $self->parseWps ($wps1, $wps2);
    ref $ret or return $ret;
    my ($word1, $pos1, $sense1, $offset1, $word2, $pos2, $sense2, $offset2) = @{$ret};
    
    unless ($pos1 = $pos2) {
      return $self->UNRELATED;
    }

    my $pos = $pos1;

    # Now check if the similarity value for these two synsets is in the cache... if so return the cached value.
    my $relatedness = $self->{doCache} ? $self->fetchFromCache ($wps1, $wps2) : undef;
    defined $relatedness and return $relatedness;

    my @Depths1 = $self->getSynsetDepth ($offset1, $pos1);
    my @Depths2 = $self->getSynsetDepth ($offset2, $pos2);
    my $MinDepth1=999999;
    my $MinDepth2=999999;
    
    foreach (@Depths1) { 
        my $depth;
	($depth) = @{$_}; 
# ***	print "D1:$depth ";
	$MinDepth1=$depth if $depth<$MinDepth1;
    }
    
    foreach (@Depths2) {
        my $depth;
	($depth) = @{$_}; 
# ***	print "D2:$depth ";
	$MinDepth2=$depth if $depth<$MinDepth2;
    }
    

    # Otherwise try to really find the relatedness
    # Using the methods of DepthFinder et al.

    my @LCSs = $self->getLCSbyPath ($offset1, $offset2, $pos1, 'offset');
   
    # check if there is no path between synsets
    unless (defined $LCSs[0]) {
      return $self->UNRELATED;
    }

    # find the LCS (well, path really) that is in the deepest taxonomy
    my $TaxonomyDepth = -1;
    my $length;
    foreach (@LCSs) {
	my $lcs;
	($lcs, $length) = @{$_};

	my @roots = $self->getTaxonomies ($lcs, $pos1);
## print "lcs:$lcs pos1:$pos1 length:$length ";

	foreach my $root (@roots) {
	    my $depth = $self->getTaxonomyDepth ($root, $pos1);
	    unless (defined $depth) {
		$self->{error} = $self->{error} < 1 ? 1 : $self->{error};
		$self->{errorString} .="\nWarning (${class}::getRelatedness()) - ";
		$self->{errorString} .= "Taxonomy depth for $root undefined.";
		return undef;
	    }
	    if ($depth > $TaxonomyDepth) {
	      $TaxonomyDepth = $depth;
#  print "\t maxdepth:$TaxonomyDepth\t";
	    }
	}
    }

    if ($TaxonomyDepth <= 0) {
	$self->{error} = $self->{error} < 1 ? 1 : $self->{error};
	$self->{errorString} .= "\nWarning (${class}::getRelatedness()) - ";
	$self->{errorString} .= "Max depth of taxonomy is not positive.";
	return undef;
    }

## print "$offset1, $offset2";
 
    my $similarity_score = -1 * log ($length / (2 * $TaxonomyDepth) );
    my $MaxDepth12=$MinDepth1;
#     my $TaxDepth=$self->getTaxonomyDepth ($root, $pos1);
    
    $MaxDepth12=$MinDepth2 if $MaxDepth12<$MinDepth2 ;
    my $lengthfactor = ($length-1)/$TaxonomyDepth;
#    my $depthfactor = abs($MinDepth1-$MinDepth2) / $MaxDepth12;
    my $depthfactor = abs($MinDepth1-$MinDepth2) / $TaxonomyDepth;    

    my $my_similarity_score = 1 / (1 + $LengthConstant*$lengthfactor + $DepthConstant*$depthfactor);

# PRINT DEBUG INFORMATION    
#  print "\nLCH:$similarity_score\tMY:$my_similarity_score\tLN:$length\tTD:$TaxonomyDepth\tLF:$lengthfactor\tDF:$depthfactor\tD1:$MinDepth1\tD2:$MinDepth2 ";
# print "$length\t$TaxonomyDepth,$MaxDepth12\t$MinDepth1\t$MinDepth2 ";
# my @gloss1=$wn->querySense($wps1, "glos");
# my @gloss2=$wn->querySense($wps2, "glos");
# print "\t$wps1 - $wps2\t@gloss1 - @gloss2";

    $self->storeToCache ($offset1, $offset2, $my_similarity_score);

    return $my_similarity_score;
}



=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005, Ted Pedersen, Siddharth Patwardhan and Jason Michelizzi

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to

    The Free Software Foundation, Inc.,
    59 Temple Place - Suite 330,
    Boston, MA  02111-1307, USA.

Note: a copy of the GNU General Public License is available on the web
at <http://www.gnu.org/licenses/gpl.txt> and is included in this
distribution as GPL.txt.

=cut
