#!/usr/local/bin/perl -w
#
# readDB.pl ver 0.01
# (Last updated 09/27/2003 -- Sid)
# 
# Program to read a wordvector BerkeleyDB file and print one or
# all vectors in it.
#
# Copyright (c) 2002-2003
#
# Ted Pedersen, University of Minnesota, Duluth
# tpederse@d.umn.edu
#
# Siddharth Patwardhan, University of Utah, Salt Lake City
# sidd@cs.utah.edu
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
# along with this program; if not, write to:
#
#    The Free Software Foundation, Inc.,
#    59 Temple Place - Suite 330,
#    Boston, MA  02111-1307, USA.
#
#
#-----------------------------------------------------------------------------

use BerkeleyDB;

my %wordMatrix;
my %dbHash;
my %subHash;
my $fname = shift;
my $sname = shift;
my $word = shift;
my $line;

if(!defined $fname || !defined $word || !defined $sname)
{
    print "Usage: readDB.pl DBFILE SUBNAME {WORD | --all}\n\n";
    print "DBFILE       is the name of the database file that contains the\n";
    print "             word vectors.\n\n";
    print "SUBNAME      The word vector database contains three subtables --\n";
    print "             'Dimensions', 'DocumentCount' and 'Vectors'.\n\n";
    print "             The 'Dimensions' table contains an entry for each\n";
    print "             word that is a dimension of the word vectors. The\n";
    print "             \"value\" corresponding to each word in this table is\n";
    print "             a sequence of three space separated integers --\n";
    print "               (a) the index of the word in the vector.\n";
    print "               (b) its term frequency.\n";
    print "               (c) its document frequency.\n\n";
    print "             The 'DocumentCount' table contains only a single row,\n";
    print "             which has as its key and value the count of the\n";
    print "             number of documents that were read to form the word\n";
    print "             vectors. The term frequency, document frequency and\n";
    print "             the document count are all required for computing the\n";
    print "             tf/idf value of each word.\n\n";
    print "             The 'Vectors' table contains the actual word vectors.\n";
    print "             The keys of this table are the content words. Its\n";
    print "             values are of the form:\n\n";
    print "               index1 count1 index2 count2 index3 count3 ...\n\n";
    print "             The 'index' corresponds to the index of the dimension\n";
    print "             (The word corresponding to the dimension is determined\n";
    print "             from the 'Dimensions' table). The 'count' is the\n";
    print "             co-occurrence count of the word.\n\n";
    print "WORD         selects the word (key) from the table, whose value\n";
    print "             (vector / index and counts) should be displayed.\n\n";
    print "--all        Displays values for all the keys in the table. Be\n";
    print "             careful when using this option with the 'Dimensions'\n";
    print "             and 'Vectors' tables (they are really big and the\n";
    print "             output goes on forever). This option is, however, the\n";
    print "             natural choice for the 'DocumentCount' table.\n\n";
    exit;
}

tie %dbHash, "BerkeleyDB::Hash", Filename => $fname,  Subname => $sname or die "Unable to open $fname: $! 
$BerkeleyDB::Error\n";

print STDERR "Searching for '$word'... \n";
if($word eq "--all")
{
    print STDERR "\n";
    while(($key, $value) = each %dbHash)
    {
#	%subHash = split(/\s+/, $value);
#	@keys = keys %subHash;
	print "$key => $value\n";
    }
}
else
{
    $line = $dbHash{$word};
    if(defined $line)
    {
#	%subHash = split(/\s+/, $line);
#	@keys = keys %subHash;
	print STDERR "$word => $line\n";
#	foreach $key (keys %subHash)
#	{
#	    print "$key $subHash{$key}\n";
#	}
    }
    else
    {
	print STDERR "Not present in database.\n";
    }
}

untie %dbHash;
