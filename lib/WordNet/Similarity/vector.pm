# WordNet::Similarity::vector.pm version 0.13
# (Last updated $Id: vector.pm,v 1.15 2005/04/28 22:48:42 jmichelizzi Exp $)
#
# Module to accept two WordNet synsets and to return a floating point
# number that indicates how similar those two synsets are, using a
# gloss vector overlap measure based on "context vectors" described by
# Schütze (1998).

package WordNet::Similarity::vector;

=head1 NAME

WordNet::Similarity::vector - placeholder

=head1 DESCRIPTION

This module is just a placeholder.  The WordNet::Similarity::vector module
has been removed in this release of WordNet-Similarity, but it will return
in a future version.  Please see the new WordNet::Similarity::vector_pairs
module.

=over

=cut

use strict;
use vectorFile;
our $VERSION = '0.13';

sub new
{
    print STDERR "Error: This module is just a stub.\n";
    print STDERR "The WordNet::Similarity::vector module has been removed\n";
    print STDERR "from this release of WordNet-Similarity, but it will be\n";
    print STDERR "included in a future release.  Please see the new\n";
    print STDERR "WordNet::Similarity::vector_pairs module for similar\n";
    print STDERR "functionality.\n";
    return undef;
}

1;

__END__

=back

=head1 SEE ALSO

perl(1), WordNet::Similarity(3), WordNet::QueryData(3),
WordNet::Similarity::vector_pairs(3)

http://www.cs.utah.edu/~sidd

http://www.cogsci.princeton.edu/~wn

http://www.ai.mit.edu/~jrennie/WordNet

http://groups.yahoo.com/group/wn-similarity

=head1 AUTHORS

 Siddharth Patwardhan, University of Utah, Salt Lake City
 sidd at cs.utah.edu

 Ted Pedersen, University of Minnesota, Duluth
 tpederse at d.umn.edu

 Satanjeev Banerjee, Carnegie Mellon University, Pittsburgh
 banerjee+ at cs.cmu.edu

=head1 BUGS

To report bugs, go to http://groups.yahoo.com/group/wn-similarity/ or
send an e-mail to "S<tpederse at d.umn.edu>".

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003-2005, Siddharth Patwardhan, Ted Pedersen and Satanjeev
Banerjee

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
