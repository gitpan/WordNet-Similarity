# WordNet::Similarity::DepthFinder version 0.07
# (Updated 3/04/2004 -- Jason)
#
# Module containing code to find the depths of (noun and verb) synsets in
# the WordNet 'is-a' taxonomies

package WordNet::Similarity::DepthFinder;

=head1 NAME

WordNet::Similarity::DepthFinder - methods to find the depth of synsets in
WordNet taxonomies

=head1 SYNOPSIS

use WordNet::QueryData;

use WordNet::Similarity::DepthFinder;

my $wn = WordNet::QueryData->new;

defined $wn or die "Construction of WordNet::QueryData failed";

my $obj = WordNet::Similarity::DepthFinder->new ($wn);

my ($err, $errString) = $obj->getError ();

$err and die $errString;

my @roots = $obj->getTaxonomyRoot (2855301, 'n');

my $taxonomy_depth = $obj->getTaxonomyDepth ($roots[0], 'n');

print "The maximum depth of the car#n#4's taxonomy is $taxonomy_depth\n";

my @depths = $obj->getSynsetDepth (2855301, 'n');

print "The depth of car#n#4 is $depths[0]->[0]\n";

=head1 DESCRIPTION

The following methods are provided by this module:

=over

=cut

use strict;
use warnings;

use WordNet::Similarity::ICFinder;

our @ISA = qw/WordNet::Similarity::ICFinder/;

our $VERSION = '0.07';

WordNet::Similarity::addConfigOption ("taxonomyDepthsFile", "p", 1, undef);
WordNet::Similarity::addConfigOption ("synsetDepthsFile", "p", 1, undef);

=item $obj->initialize ($configfile)

Overrides the initialize method in WordNet::Similarity to look for and
process depths files.  The superclass' initialize method is also called.

=cut

sub initialize
{
    my $self = shift;
    my $class = ref $self || $self;

    my $wn = $self->{wn};
    my $wnversion = $wn->version ();

    my $defaultdepths = "synsetdepths-${wnversion}.dat";
    my $defaultroots = "treedepths-${wnversion}.dat";

    $self->SUPER::initialize (@_);

    my $depthsfile = $self->{synsetDepthsFile};

    unless (defined $depthsfile) {
    DEPTHS_SEARCH:
	foreach (@INC) {
	    my $file = File::Spec->catfile ($_, 'WordNet', $defaultdepths);
	    if (-e $file) {
		if (-r $file) {
		    $depthsfile = $file;
		    last DEPTHS_SEARCH;
		}
		else {
		    # The file not readable--is this an error?
		    # I suppose we shouldn't punish people for having
		    # unreadable files lying around; let's do nothing.
		}
	    }
	}
    }

    unless (defined $depthsfile) {
	$self->{error} = 2;
	$self->{errorString} .= "\nError (${class}::initialize()) - ";
	$self->{errorString} .= "No depths file found.";
	return undef;
    }

    $self->_processSynsetsFile ($depthsfile) or return undef;

    my $rootsfile = $self->{treeDepthsFile};

    unless (defined $rootsfile) {
    TAXONOMY_SEARCH:
	foreach (@INC) {
	    my $file = File::Spec->catfile ($_, 'WordNet', $defaultroots);
	    if (-e $file) {
		if (-r $file) {
		    $rootsfile = $file;
		    last TAXONOMY_SEARCH;
		}
		else {
		    # The file not readable--is this an error?
		    # I suppose we shouldn't punish people for having
		    # unreadable files lying around; let's do nothing.
		}
	    }
	}
    }

    $self->_processTaxonomyFile ($rootsfile) or return undef;

    return 1;
}


=item $obj->getSynsetDepth ($offset, $pos)

Returns the depth(s) of the synset denoted by $offset and $pos.  The return
value is a list of references to arrays.  Each array has the form
S<(depth, root)>.

=cut

sub getSynsetDepth
{
    my $self = shift;
    my $class = ref $self || $self;
    my $offset = shift;
    my $pos = shift;

    my $ref = $self->{depths}->{$pos}->{$offset};
    my @depths = @$ref;


    unless (defined $depths[0]) {
	$self->{errorString} .= "\nWarning (${class}::getSynsetDepth()) - ";
	$self->{errorString} .= "No depth found for '$offset#$pos'.";
	$self->{error} = $self->{error} < 1 ? 1 : $self->{error};
	return undef;
    }

    return @depths;
}


=item $obj->getTaxonomyDepth ($offset, $pos)

Returns the maximum depth of the taxonomy rooted at the synset identified
by $offset and $pos.  If $offset and $pos does not identify a root of
a taxonomy, then undef is returned and an error is raised.

=cut

sub getTaxonomyDepth
{
    my $self = shift;
    my $class = ref $self || $self;
    my $synset = shift;
    my $pos = shift;

    my $depth = $self->{taxonomyDepths}->{$pos}->{$synset};

    unless (defined $depth) {
	$self->{error} = $self->{error} < 1 ? 1 : $self->{error};
	$self->{errorString} .= "\nWarning (${class}::getTaxonomyDepth()) - ";
	$self->{errorString} .= "No taxonomy is rooted at $synset#$pos.";
	return undef;
    }

    return $depth;
}

=item $obj->getTaxonomies ($offset, $pos)

Returns a list of the roots of the taxonomies to which the synset identified
by $offset and $pos belongs.

=cut

sub getTaxonomies
{
    my $self = shift;
    my $offset = shift;
    my $pos = shift;
    my $class = ref $self || $self;

    my $ref = $self->{depths}->{$pos}->{$offset};
    my @tmp = @$ref;
    my %tmp;
    foreach (@tmp) {
	$tmp{$_->[1]} = 1;
    }
    my @rtn = keys %tmp;
    unless (defined $rtn[0]) {
	$self->{errorString} .= "\nWarning (${class}::getTaxonomies()) - ";
	$self->{errorString} .= "No root information for $offset#$pos.";
	$self->{error} = $self->{error} < 1 ? 1 : $self->{error};
	return undef;
    }
    return @rtn;
}

=item $obj->_processSynsetsFile ($filename)

Reads and processes a synsets file as output by wnDepths.pl

=cut

sub _processSynsetsFile
{
    my $self = shift;
    my $file = shift;
    my $class = ref $self || $self;
    my $wnver = $self->{wn}->version ();

    unless (open FH, '<', $file) {
	$self->{error} = 2;
	$self->{errorString} .= "\nError (${class}::_processSynsetsFile()) - ";
	$self->{errorString} .= "Cannot open $file for reading: $!.";
	return 0;
    }

    my $line = <FH>;
    unless ($line =~ /^wnver::([\d.]+)$/) {
	$self->{errorString} .= "\nError (${class}::_processSynsetsFile()) - ";
	$self->{errorString} .= "File $file has bad format.";
	$self->{error} = 2;
	return 0;
    }
    unless ($1 eq $wnver) {
	$self->{errorString} .= "\nError (${class}::_processSynsetsFile()) - ";
	$self->{errorString} .= "Bad WordNet version in $file, $1, should be $wnver.";
	$self->{error} = 2;
	return 0;
    }

    # If we are using a root node, then we need to slightly adjust all
    # the synset depths.  Thus, the correction will be 1 if the root node
    # is on and 0 otherwise.
    my $correction = $self->{rootNode} ? 1 : 0;

    while ($line = <FH>) {
	my ($pos, $offset, @depths) = split /\s+/, $line;
	# convert the offset string to a number.  When we make the number
	# into a string again, there won't be any leading zeros.
	$offset = 0 + $offset;

	# We assume the the first depth listed is the smallest.
	# The wnDepths.pl program should guarantee this behavior.
	my @refs;
	foreach (@depths) {
	    my ($depth, $root) = split /:/;
	    # make root a number; see above for why.  If the root node
	    # is on, then all roots are the root node, so adjust for that.
	    $root = $self->{rootNode} ? 0 : $root + 0;
	    $depth += $correction;
	    push @refs, [$depth, $root];
	}
	$self->{depths}->{$pos}->{$offset} = [@refs];
    }

    if ($self->{rootNode}) {
	# set the depth of the root nodes to be one
	$self->{depths}->{n}->{0} = [[1, 0]];
	$self->{depths}->{v}->{0} = [[1, 0]];
    }

    return 1;
}

=item $obj->_processTaxonomyFile ($filename)

Reads and processes a taxonomies file as produced by wnDepths.pl

=cut

sub _processTaxonomyFile
{
    my $self = shift;
    my $filename = shift;
    my $class = ref $self || $self;

    unless (open FH, '<', $filename) {
	$self->{errorString} .= "Error (${class}::_processTaxonomyFile()) - ";
	$self->{errorString} .= "Could not open '$filename' for reading: $!.";
	$self->{error} = 2;
	return 0;
    }

    my $line = <FH>;

    unless ($line =~ /^wnver::([\d.]+)$/) {
	$self->{errorString} .= "Error (${class}::_processTaxonomyFile()) - ";
	$self->{errorString} .= "Bad file format for $filename.";
	$self->{error} = 2;
	return 0;
    }

    while ($line = <FH>) {
	my ($p, $o, $d) = split /\s+/, $line;

	# add 0 to offset to make it a number; see above for why
	$o = $o + 0;

        $self->{taxonomyDepths}->{$p}->{$o} = $d;
    }

    close FH;
    return 1;
}

1;

__END__

=back

=head1 AUTHORS

 Jason Michelizzi, University of Minnesota Duluth
 mich0212 at d.umn.edu

 Ted Pedersen, University of Minnesota Duluth
 tpederse at d.umn.edu

=head1 BUGS

None.

To report bugs, e-mail tpederse at d.umn.edu or go to
http://groups.yahoo.com/group/wn-similarity/.

=head1 SEE ALSO

WordNet::Similarity(3)
WordNet::Similarity::wup(3)
WordNet::Similarity::lch(3)

=head1 COPYRIGHT

Copyright (C) 2004, Jason Michelizzi and Ted Pedersen

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to

 The Free Software Foundation, Inc.,
 59 Temple Place - Suite 330,
 Boston, MA  02111-1307, USA.

Note: a copy of the GNU General Public License is available on the web
at L<http://www.gnu.org/licenses/gpl.txt> and is included in this
distribution as GPL.txt.

=cut