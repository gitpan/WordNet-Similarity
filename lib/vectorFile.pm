# vectorFile.pm version 0.01
# (Last updated $Id: vectorFile.pm,v 1.2 2004/10/23 07:22:52 sidz1979 Exp $)
#
# Package used by WordNet::Similarity::vector module that
# computes semantic relatedness of word senses in WordNet
# using gloss vectors. This module provides a read/write
# interface into the word vectors file.
#
# Copyright (c) 2004,
#
# Siddharth Patwardhan, University of Utah, Salt Lake City
# sidd at cs.utah.edu
#
# Ted Pedersen, University of Minnesota, Duluth
# tpederse at d.umn.edu
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

package vectorFile;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '0.01';

# Read the word vectors from a file.
sub readVectors
{
    my $className = shift;
    my $fname = shift;
    my $state = 0;
    my $docCount = 0;
    my $dimensions = {};
    my $vectors = {};
    my @parts = ();

    # Check that input values are defined.
    return (undef, undef, undef) if(!defined $className || !defined $fname || ref $className);
    
    # Read the data.
    open(IPFILE, $fname) || return (undef, undef, undef);
    while(<IPFILE>)
    {
        s/[\r\f\n]//g;
        s/^\s+//;
        s/\s+$//;
        if($state == 0)
        {
            if(/DOCUMENTCOUNT\s*=\s*([0-9]+)/)
            {
                $docCount = $1;
            }
            elsif(/--Dimensions Start--/)
            {
                $state = 1;
            }
            elsif(/--Vectors Start--/)
            {
                $state = 2;
            }
        }
        elsif($state == 1)
        {
            if(/--Dimensions End--/)
            {
                $state = 0;
            }
            elsif(/^--Dimensions/ || /^--Vectors/)
            {
                return (undef, undef, undef);
            }
            elsif($_ ne "")
            {
                @parts = split(/\s+/, $_, 2);
                $dimensions->{$parts[0]} = $parts[1];
            }
        }
        elsif($state == 2)
        {
            if(/--Vectors End--/)
            {
                $state = 0;
            }
            elsif(/^--Dimensions/ || /^--Vectors/)
            {
                return (undef, undef, undef);
            }
            elsif($_ ne "")
            {
                @parts = split(/\s+/, $_, 2);
                $vectors->{$parts[0]} = $parts[1];
            }
        }
        else
        {
            return (undef, undef, undef);
        }
    }
    close(IPFILE);

    # Return the data read.
    return ($docCount, $dimensions, $vectors);
}

# Write the word vectors to a file.
sub writeVectors
{
    my $className = shift;
    my $fname = shift;
    my $documentCount = shift;
    my $dimensions = shift;
    my $vectors = shift;

    # Check that all input values are defined.
    return 0 if(!defined $className || !defined $fname || !defined $documentCount || !defined $dimensions || !defined $vectors);
    
    # Check that the className and filename aren't references.
    return 0 if(ref $className || ref $fname);

    # Check that document count is numeric.
    return 0 if($documentCount !~ /^[0-9]+$/);

    # Write the data to the file...
    # WARNING: No integrity check of data is performed.
    open(OPFILE, ">$fname") || return 0;
    print OPFILE "DOCUMENTCOUNT=$documentCount\n";
    print OPFILE "--Dimensions Start--\n";
    foreach my $key (keys %{$dimensions})
    {
        print OPFILE "$key ".($dimensions->{$key})."\n";
    }
    print OPFILE "--Dimensions End--\n";
    print OPFILE "--Vectors Start--\n";
    foreach my $key (keys %{$vectors})
    {
        print OPFILE "$key ".($vectors->{$key})."\n";
    }
    print OPFILE "--Vectors End--\n";
    close(OPFILE);
    
    # Success.
    return 1;
}

1;
