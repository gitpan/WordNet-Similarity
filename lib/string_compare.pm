# string_compare.pm version 0.03
# (Updated 03/10/2003 -- Sid)
#
# Package used by WordNet::Similarity::lesk module that
# computes semantic relatedness of word senses in WordNet
# using gloss overlaps.
#
# Copyright (c) 2003,
# Satanjeev Banerjee, Carnegie Mellon University, Pittsburgh
# banerjee+@cs.cmu.edu
# Ted Pedersen, University of Minnesota, Duluth
# tpederse@d.umn.edu
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to 
#
# The Free Software Foundation, Inc., 
# 59 Temple Place - Suite 330, 
# Boston, MA  02111-1307, USA.

package string_compare;

use stem;

use Exporter;

@ISA = qw (Exporter);

@EXPORT = qw (string_compare_initialize string_compare_getStringOverlaps);

my $stemmingReqd;
my $wn;
my $stemmer;

# function to set up the stop hash
sub string_compare_initialize
{
    # find out if stemming is required
    $stemmingReqd = shift;
    
    if ($stemmingReqd)
    {
	# get the wordnet object
	$wn = shift; 
	
	# and finally initialize the stemming module using the wordnet object
	$stemmer=stem->new($wn);
    }
    
    # get the stop hash
    %stopHash = @_;
}

# function to compare two strings and return all overlaps in a
# hash. overlaps are keys and no of occurrences is the value
sub string_compare_getStringOverlaps
{
    my $string0 = shift;
    my $string1 = shift;
    my %overlapsHash = ();
    
    $string0 =~ s/^\s+//;
    $string0 =~ s/\s+$//;
    $string1 =~ s/^\s+//;
    $string1 =~ s/\s+$//;
    
    # if stemming on, stem the two strings
    if ($stemmingReqd)
    {
	$string0 = $stemmer->stemString($string0, 1); # 1 turns on cacheing
	$string1 = $stemmer->stemString($string1, 1);
    }
    
    my @words = split /\s+/, $string0;
    
    # for each word in string0, find out how long an overlap can start from it. 
    my @overlapLengths = ();
    
    my $matchStartIndex = 0;
    my $currIndex = -1;
    while ($currIndex < $#words)
    {
	# forward the current index to look at the next word
	$currIndex++;
	
	# form the string
	my $temp = join (" ", @words[$matchStartIndex...$currIndex]);
	
	# if this works, carry on!
	next if ($string1 =~ /\b$temp\b/);
	
	# otherwise store length is $overlapLengths[$matchStartIndex];
	$overlapsLengths[$matchStartIndex] = $currIndex - $matchStartIndex;
	$currIndex-- if ($overlapsLengths[$matchStartIndex] > 0);
	$matchStartIndex++;
    }
    
    my $i; 
    for ($i = $matchStartIndex; $i <= $currIndex; $i++)
    {
	$overlapsLengths[$i] = $currIndex - $i + 1;
    }
    
    my ($longestOverlap) = sort {$b <=> $a} @overlapsLengths;
    while (defined($longestOverlap) && ($longestOverlap > 0))
    {
	for ($i = 0; $i <= $#overlapsLengths; $i++)
	{
	    next if ($overlapsLengths[$i] < $longestOverlap);
	    
	    # form the string
	    my $stringEnd = $i + $longestOverlap - 1;
	    my $temp = join (" ", @words[$i...$stringEnd]);
	    
	    # check if still there in $string1. if so, replace in string1 with a mark
	    if (!doStop($temp) && $string1 =~ s/$temp/XXX/)
	    {
		# so its still there. we have an overlap!
		$overlapsHash{$temp}++;
		
		# adjust overlap lengths forward
		my $j = $i;
		for (; $j < $i + $longestOverlap; $j++)
		{
		    $overlapsLengths[$j] = 0;
		}
		
		# adjust overlap lengths backward
		for ($j = $i-1; $j >= 0; $j--)
		{
		    last if ($overlapsLengths[$j] <= $i - $j);
		    $overlapsLengths[$j] = $i - $j;
		}
	    }
	    else
	    {
		# ah its not there any more in string1! see if
		# anything smaller than the full string works
		my $j = $longestOverlap - 1;
		while ($j > 0)
		{
		    # form the string
		    my $stringEnd = $i + $j - 1;
		    my $temp = join (" ", @words[$i...$stringEnd]);
		    
		    last if ($string1 =~ /\b$temp\b/);
		    $j--;
		}
		
		$overlapsLengths[$i] = $j;
	    }
	}
	($longestOverlap) = sort {$b <=> $a} @overlapsLengths;
    }
    return (%overlapsHash);
}

# function to decide whether or not to stop a given overlap
sub doStop
{
    my @words = split(/\s+/, shift); 
    my $word;
    
    # if first word or last word non-content, stop
    return ((defined $stopHash{$words[0]} || defined $stopHash{$words[$#words]})?1:0);
}

1;

