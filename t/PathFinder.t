#!/usr/local/bin/perl

# PathFinder.t version 0.07
# (Updated 1/12/2004 -- Jason)
#
# Copyright (C) 2004
#
# Jason Michelizzi, University of Minnesota Duluth
# mich0212 at d.umn.edu
#
# Ted Pedersen, University of Minnesota Duluth
# tpederse at d.umn.edu

# Before 'make install' is run this script should be runnable with
# 'make test'.  After 'make install' it should work as 'perl PathFinder.t'

# A script to run tests on the WordNet::Similarity::PathFinder module.
# The following are among the tests run by this script:
# 1) Using offsets:
#   a) test the shortest path between identical synsets
#   b) test the shortest path between a synset and its immediate hypernym
#   c) various other tests of shortest path
# 2) Using wps: cases are similar to the above

use strict;
use warnings;

use Test::More tests => 21;

BEGIN {use_ok ('WordNet::QueryData')}
BEGIN {use_ok ('WordNet::Similarity::PathFinder')}

my $wn = WordNet::QueryData->new;
ok ($wn) or diag "Failed to construct WordNet::QueryData object";

my $module = WordNet::Similarity::PathFinder->new ($wn);
ok ($module)
  or diag ("Failed to construct WordNet::Similarity::PathFinder object");
my ($err, $errstr) = $module->getError();
is ($err, 0) or diag "$errstr\n";

# run a few tests finding Least Common Subsumers (LCSs)

# a few variables that we'll need repeatedly
my $offset1;
my $offset2;
my $word1;
my $word2;
my @tree1;
my @tree2;
my $len;
my @paths;
my $path;

# start by testing the methods that use offsets:

# levitation#n#1 and levitation#n#1, using offsets

# writing like this: 0 + 'numeric_offset' causes the result
# to be numeric--simply writing 'numeric_offset' results
# in a string, which can cause problems later, and not quoting
# the offset will cause Perl to think that it is an octal number
# if it begins with 0.

$offset1 = 0 + '10670921';
$offset2 = 0 + '10670921';

@tree1 = $module->_getHypernymTrees ($offset1, 'n', 'offset');
is (($module->getError())[0], 0);
@tree2 = $module->_getHypernymTrees ($offset2, 'n', 'offset');
is (($module->getError())[0], 0);
@paths = $module->getShortestPath ($offset1, $offset2, 'n', 'offset');
$len = $paths[0]->[0];
#($len, $path) = $module->getShortestPath ($offset1, $offset2, 'n', 'offset');
is (($module->getError())[0], 0);
is ($len, 1);

# organ#n#1 and sucker#n#6
$offset1 = 0 + '04992592';
$offset2 = 0 + '02377231';
@tree1 = $module->_getHypernymTrees ($offset1, 'n', 'offset');
@tree2 = $module->_getHypernymTrees ($offset2, 'n', 'offset');
@paths = $module->getShortestPath ($offset1, $offset2, 'n', 'offset');
$len = $paths[0]->[0];
is (($module->getError())[0], 0);
is ($len, 2);

# remember#v#2 and keep_note#v#1
$offset1 = 0 + '00589832';
$offset2 = 0 + '00712981';
@tree1 = $module->_getHypernymTrees ($offset1, 'v', 'offset');
@tree2 = $module->_getHypernymTrees ($offset2, 'v', 'offset');
@paths = $module->getShortestPath ($offset1, $offset2, 'v', 'offset');
$len = $paths[0]->[0];
is (($module->getError())[0], 0);
is ($len, 2);

# entity#n#1 and phenomenon#n#1
$offset1 = 0 + '00001740';
$offset2 = 0 + '00029881';
@tree1 = $module->_getHypernymTrees ($offset1, 'n', 'offset');
@tree2 = $module->_getHypernymTrees ($offset2, 'n', 'offset');
@paths = $module->getShortestPath ($offset1, $offset2, 'n', 'offset');
$len = $paths[0]->[0];
is (($module->getError())[0], 0);
is ($len, 3);

# sky#n#1 and anticipation#n#4
$offset1 = 0 + '08843058';
$offset2 = 0 + '08626236';
@tree1 = $module->_getHypernymTrees ($offset1, 'n', 'offset');
@tree2 = $module->_getHypernymTrees ($offset2, 'n', 'offset');
@paths = $module->getShortestPath ($offset1, $offset2, 'n', 'offset');
$len = $paths[0]->[0];
is (($module->getError ())[0], 0);
is ($len, 3);

# now try the methods that use wps strings

# auto#n#1 and motor_vehicle#n#1
$word1 = 'auto#n#1';
$word2 = 'motor_vehicle#n#1';
@tree1 = $module->_getHypernymTrees ($word1, 'n', 'wps');
@tree2 = $module->_getHypernymTrees ($word2, 'n', 'wps');
@paths = $module->getShortestPath ($word1, $word2, 'n', 'wps');
$len = $paths[0]->[0];
is (($module->getError())[0], 0);
is ($len, 2);

# remember#v#2 and keep_note#v#1
$word1 = 'remember#v#2';
$word2 = 'keep_note#v#1';
@tree1 = $module->_getHypernymTrees ($word1, 'v', 'wps');
@tree2 = $module->_getHypernymTrees ($word2, 'v', 'wps');
@paths = $module->getShortestPath ($word1, $word2, 'n', 'wps');
$len = $paths[0]->[0];
is (($module->getError())[0], 0);
is ($len, 2);

__END__
