#!/usr/local/bin/perl -w

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl loaded.t'

##################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..11\n"; }
END {print "not ok 1\n" unless $loaded;}
use WordNet::Similarity;
use WordNet::QueryData 1.30;
use WordNet::Similarity::jcn;
use WordNet::Similarity::res;
use WordNet::Similarity::lin;
use WordNet::Similarity::lch;
use WordNet::Similarity::hso;
use WordNet::Similarity::lesk;
use WordNet::Similarity::edge;
use WordNet::Similarity::random;
use WordNet::Similarity::vector;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

############ Load QueryData

$wn = WordNet::QueryData->new();
if($wn)
{
    print "ok 2\n";
}
else
{
    print "not ok 2\n";
}

############ Load jcn

$jcn = WordNet::Similarity::jcn->new($wn);
if($jcn)
{
    ($err, $errString) = $jcn->getError();
    if($err)
    {
        print "not ok 3\n";
    }
    else
    {
        print "ok 3\n";
    }
}
else
{
    print "not ok 3\n";
}

############ Load res

$res = WordNet::Similarity::res->new($wn);
if($res)
{
    ($err, $errString) = $res->getError();
    if($err)
    {
        print "not ok 4\n";
    }
    else
    {
        print "ok 4\n";
    }
}
else
{
    print "not ok 4\n";
}

############ Load lin

$lin = WordNet::Similarity::lin->new($wn);
if($lin)
{
    ($err, $errString) = $lin->getError();
    if($err)
    {
        print "not ok 5\n";
    }
    else
    {
        print "ok 5\n";
    }
}
else
{
    print "not ok 5\n";
}

############ Load lch

$lch = WordNet::Similarity::lch->new($wn);
if($lch)
{
    ($err, $errString) = $lch->getError();
    if($err)
    {
        print "not ok 6\n";
    }
    else
    {
        print "ok 6\n";
    }
}
else
{
    print "not ok 6\n";
}

############ Load hso

$hso = WordNet::Similarity::hso->new($wn);
if($hso)
{
    ($err, $errString) = $hso->getError();
    if($err)
    {
        print "not ok 7\n";
    }
    else
    {
        print "ok 7\n";
    }
}
else
{
    print "not ok 7\n";
}

############ Load lesk

$lesk = WordNet::Similarity::lesk->new($wn);
if($lesk)
{
    ($err, $errString) = $lesk->getError();
    if($err)
    {
        print "not ok 8\n";
    }
    else
    {
        print "ok 8\n";
    }
}
else
{
    print "not ok 8\n";
}

############ Load edge

$edge = WordNet::Similarity::edge->new($wn);
if($edge)
{
    ($err, $errString) = $edge->getError();
    if($err)
    {
        print "not ok 9\n";
    }
    else
    {
        print "ok 9\n";
    }
}
else
{
    print "not ok 9\n";
}

############ Load random

$random = WordNet::Similarity::random->new($wn);
if($random)
{
    ($err, $errString) = $random->getError();
    if($err)
    {
        print "not ok 10\n";
    }
    else
    {
        print "ok 10\n";
    }
}
else
{
    print "not ok 10\n";
}

############ Load vector

$vector = WordNet::Similarity::vector->new($wn);
if($vector)
{
    ($err, $errString) = $vector->getError();
    if($err)
    {
	# Vector module REQUIRES a config file...
	# So it is Ok if it returns an error during
	# initialization without config file.
        print "ok 11\n";
    }
    else
    {
        print "not ok 11\n";
    }
}
else
{
    print "not ok 11\n";
}

