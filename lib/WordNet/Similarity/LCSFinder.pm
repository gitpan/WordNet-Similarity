# WordNet::Similarity::LCSFinder.pm version 0.10
# (Updated 9/01/2004 -- Jason)
#
# Module that finds the LCS of two synsets.


package WordNet::Similarity::LCSFinder;

=head1 NAME

WordNet::Similarity::LCSFinder - methods for finding Least Common Subsumers

=head1 SYNOPSIS

use WordNet::QueryData;

my $wn = WordNet::QueryData->new;

my $obj = WordNet::Similarity::LCSFinder->new ($wn);

my ($lcs, $depth) = $obj->getLCSbyDepth ("scientist#n#1", "poet#n#1", "n", "wps");

my ($lcs, $pathlen) = $obj->getLCSbyPath ("dog#n#1", "cat#n#1", "n", "wps");

my ($lcs, $ic) = $obj->getLCSbyIC ("dog#n#1", "cat#n#1", "n", "wps");

=head1 DESCRIPTION

The following methods are declared in this module:

=over

=cut

use strict;
use warnings;

use WordNet::Similarity::DepthFinder;

our @ISA = qw/WordNet::Similarity::DepthFinder/;

our $VERSION = '0.10';

=item getLCSbyDepth($synset1, $synset2, $pos, $mode)

Given two input synsets, finds the least common subsumer (LCS) of them.
If there are multiple candidates for the LCS (due to multiple inheritance
in WordNet), the LCS with the greatest depth is chosen (i.e., the candidate
whose shortest path to the root is the longest).

Parameters: a blessed reference, two synsets, a part of speech, and a mode.
The mode must the either the string 'wps' or 'offset'.  If the mode is wps,
then the two input synsets must be in word#pos#sense format.  If the mode
is offset, then the input synsets must be WordNet offsets.

Returns: a list of the form ($lcs, $depth) where $lcs is the LCS (in wps
format if mode is 'wps' or an offset if mode is 'offset'.  $depth is the
depth of the LCS in its taxonomy.  Returns undef on error.

=cut

sub getLCSbyDepth
{
  my $self = shift;
  my $synset1 = shift;
  my $synset2 = shift;
  my $pos = shift;
  my $mode = shift;
  my $class = ref $self || $self;

  my @paths = $self->getAllPaths ($synset1, $synset2, $pos, $mode);
  unless (defined $paths[0]) {
    # no paths found
    $self->{error} = $self->{error} < 1 ? 1 : $self->{error};
    $self->{errorString} .= "\nWarning (${class}::getLCSbyDepth()) - ";
    $self->{errorString} .= "No path between synsets found.";
    return $self->UNRELATED;
  }

  my $wn = $self->{wn};
  my %depth;           # a hash to hold the depth of each LCS candidate

  # find the depth of each LCS candidate
  foreach (@paths) {
    my $offset = $_->[0];
    if ($mode eq 'wps') {
      if (index ($_->[0], "*Root*") >= $[) {
	$offset = 0;
      }
      else {
	$offset = $wn->offset ($_->[0]);
      }
    }

    my @depths = $self->getSynsetDepth ($offset, $pos);
    my ($depth, $root) = @{$depths[0]};
    unless (defined $depth) {
      # serious internal error -- possible problem with depths file?
      $self->{error} = $self->{error} < 1 ? 1 : $self->{error};
      $self->{errorString} .= "\nWarning (${class}::getLCSbyDepth()) - ";
      $self->{errorString} .= "Undefined depth for $_->[0].  ";
      $self->{errorString} .= "Possible problem with the depths file?";
      return undef;
    }
    $depth{$_->[0]} = [$depth, $root];
  }

  # sort according to depth (descending order)
  my @tmp = sort {$b->[1] <=> $a->[1]} map [$_, @{$depth{$_}}], keys %depth;

  # remove from the array all the subsumers that are not tied for best
  foreach (0..$#tmp) {
    if ($tmp[$_]->[1] == $tmp[0]->[1]) {
      # do nothing
    }
    else {
      # kill the rest of the array and exit the loop
      $#tmp = $_ - 1;
      last;
    }
  }

  unless (defined $tmp[0]) {
    my $wps1 = $synset1;
    my $wps2 = $synset2;
    if ($mode eq 'offset') {
      $wps1 = $synset1 ? $wn->getSense ($synset1, $pos) : "*Root*#$pos#1";
      $wps2 = $synset2 ? $wn->getSynse ($synset2, $pos) : "*Root*#$pos#1";
    }

    $self->{error} = $self->{error} < 1 ? 1 : $self->{error};
    $self->{errorString} .= "\nWarning (${class}::getLCSbyDepth() - ";
    $self->{errorString} .= "No LCS found for $wps1 and $wps2.";

    if ($self->{trace}) {
      $self->{traceString} .= "\nNo LCS found for ";
      $self->printSet ($pos, 'wps', $wps1);
      $self->{traceString} .= ", ";
      $self->printSet ($pos, 'wps', $wps2);
      $self->{traceString} .= ".";
    }
    return undef;
  }

  if ($self->{trace}) {
    $self->{traceString} .= "\nLowest Common Subsumers: ";
    foreach (@tmp) {
      $self->printSet ($pos, $mode, $_->[0]);
      $self->{traceString} .= " (Depth=$_->[1]) ";
    }
  }

  return @tmp;
}

=item getLCSbyPath($synset1, $synset2, $pos, $mode)

Given two input synsets, finds the least common subsumer (LCS) of them.
If there are multiple candidates for the LCS (due to multiple inheritance),
the LCS that results in the shortest path between in input concepts is
chosen.

Parameters: two synsets, a part of speech, and a mode.

Returns: a list of references to arrays where each array has the from
C<($lcs, $pathlength)>.  $pathlength is the length
of the path between the two input concepts.  There can be multiple LCSs
returned if there are ties for the shortest path between the two synsets.
Returns undef on error.

=cut

sub getLCSbyPath
{
  my $self = shift;
  my $synset1 = shift;
  my $synset2 = shift;
  my $pos = shift;
  my $mode = shift;
  my $class = ref $self || $self;

  my @paths = $self->getAllPaths ($synset1, $synset2, $pos, $mode);

  # if no paths were found, $paths[0] should be undefined
  unless (defined $paths[0]) {
    $self->{error} = $self->{error} < 1 ? 1 : $self->{error};
    $self->{errorString} .= "\nWarning (${class}::getLCSbyPath()) - ";
    $self->{errorString} .= "No LCS found.";
    return undef;
  }

  if ($self->{trace}) {
    $self->{traceString} .= "Lowest Common Subsumer(s): ";
  }

  my @return;

  # put the best LCS(s) into @return; do some tracing at the same time.
  foreach my $pathref (@paths) {
    if ($self->{trace}) {
      # print path to trace string
      $self->printSet ($pos, $mode, $pathref->[0]);	
      $self->{traceString} .= " (Length=".$pathref->[1].")\n";
    }

    # push onto return array if this path length is tied for best
    if ($pathref->[1] <= $paths[0]->[1]) {
      push @return, [$pathref->[0], $pathref->[1]];
    }
  }

  if ($self->{trace}) {
    $self->{traceString} .= "\n\n";
  }

  return @return;
}


=item getLCSbyIC($synset1, $synset2, $pos, $mode)

Given two input synsets, finds the least common subsumer (LCS) of them.  If
there are multiple candidates for the LCS, the the candidate with the greatest
information content.

Parameters: two synsets, a part of speech, and a mode.

Returns: a list of the form ($lcs, $ic) where $lcs is the LCS and $ic is
the information content of the LCS.

=cut

sub getLCSbyIC
{
  my $self = shift;
  my $synset1 = shift;
  my $synset2 = shift;
  my $pos = shift;
  my $mode = shift;
  my $class = ref $self || $self;

  my $wn = $self->{wn};

  my @paths = $self->getAllPaths ($synset1, $synset2, $pos, $mode);

  # check to see if any paths were found
  unless (defined $paths[0]) {
    $self->{error} = $self->{error} < 1 ? 1 : $self->{error};
    $self->{errorString} .= "\nWarning (${class}::getLCSbyIC()) - ";

    my $wps1 = $mode eq 'wps' ? $synset1 : $wn->getSense ($synset1, $pos);
    my $wps2 = $mode eq 'wps' ? $synset2 : $wn->getSense ($synset2, $pos);

    $self->{errorString} .= "No LCS found for $wps1 and $wps2.";

    if ($self->{trace}) {
      $self->{traceString} .= "\nNo LCS found for ";
      $self->printSet ($pos, $mode, $synset1);
      $self->{traceString} .= ", ";
      $self->printSet ($pos, $mode, $synset2);
      $self->{traceString} .= ".";
    }
    return undef;
  }

  my %IC;

  # get the IC of each subsumer, put it in a hash
  foreach (@paths) {
    # the "O + $off" below is a hack to cope with an unfortunate problem:
    # The offsets in the WordNet data files are zero-padded, eight-digit
    # decimal numbers.  Sometimes these numbers get stripped off (QueryData's
    # offset() method does this).  As a result, it is much easier to compare
    # the offsets as numbers rather than as strings:
    # '00001740' ne '1740', BUT 0 + '00001740' == 0 + '1740'
    my $off;
    if ($mode eq 'offset') {
      $off = $_->[0];
    }
    else {
      $off = (index ($_->[0], '*Root*') < $[) ? $wn->offset ($_->[0]) : 0;
    }

    next if defined $IC{$_->[0]};

   $IC{$_->[0]} = $self->IC (0 + $off, $pos) || 0;
  }


  # sort lcs by info content
  my @array = sort {$b->[1] <=> $a->[1]} map {[$_, $IC{$_}]} keys %IC;

  if ($self->{trace}) {
    $self->{traceString} .= "Lowest Common Subsumer(s): ";
  }

  my @return;

  # determine which subsumers have the highest info content; do some
  # tracing as well
  foreach my $ref (@array) {
    if ($self->{trace}) {
      $self->printSet ($pos, $mode, $ref->[0]);
      $self->{traceString} .= " (IC=";
      $self->{traceString} .= sprintf ("%.6f", $ref->[1]);
      $self->{traceString} .= ") ";
    }

    if ($ref->[1] == $array[0]->[1]) {
      push @return, $ref;
    }
  }

  $self->{trace} and $self->{traceString} .= "\n";

  return @return;
}


1;

__END__

=back

=head1 AUTHORS

 Jason Michelizzi, University of Minnesota Duluth
 mich0212 at d.umn.edu

 Siddharth Patwardhan, University of Utah, Salt Lake City
 sidd at cs.utah.edu

 Ted Pedersen, University of Minnesota Duluth
 tpederse at d.umn.edu

=head1 BUGS

None.

Report bugs to tpederse I<at> d.umn.edu or go to
L<http://groups.yahoo.com/group/wn-similarity> (preferred).

=head1 SEE ALSO

WordNet::Similarity(3)
WordNet::Similarity::PathFinder(3)
WordNet::Similarity::ICFinder(3)
WordNet::Similarity::res(3)
WordNet::Similarity::lin(3)
WordNet::Similarity::jcn(3)

=head1 COPYRIGHT

Copyright (C) 2004, Jason Michelizzi, Siddharth Patwardhan, and Ted Pedersen

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
at L<http://www.gnu.org/licenses/gpl.txt> and is included in this
distribution as GPL.txt.

=cut
