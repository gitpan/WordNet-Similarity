#!/usr/local/bin/perl -w

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl edge.t'

##################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..8\n"; }
END {print "not ok 1\n" unless $loaded;}
use WordNet::Similarity;
use WordNet::QueryData;
use WordNet::Similarity::edge;
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

############ Load edge

$edge = WordNet::Similarity::edge->new($wn);
if($edge)
{
    ($err, $errString) = $edge->getError();
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

############ Load edge with undef QueryData.

$badEdge = WordNet::Similarity::edge->new(undef);
if($badEdge)
{
    ($err, $errString) = $badEdge->getError();
    if($err < 2)
    {
	print "not ok 4\n";
    }
    elsif($err == 2)
    {
	if($errString =~ /A WordNet::QueryData object is required/)
	{
	    print "ok 4\n";
	}
	else
	{
	    print "not ok 4\n";
	}
    }
    else
    {
	print "not ok 4\n";
    }
}
else
{
    print "not ok 4\n";
}

############ GetRelatedness of same synset.

$value = $edge->getRelatedness("object#n#1", "object#n#1");
if($value && $value =~ /[0-9]/)
{
    if($value == 1)
    {
	print "ok 5\n";
    }
    else
    {
	print "not ok 5\n";
    }
}
else
{
    print "not ok 5\n";
}

############ getRelatedness of badly formed synset.
## (Tried getRelatedness of unknown synsets... "hjxlq#n#1", "pynbr#n#2"... 
##  QueryData complains... can't trap that error myself.)

if(defined $edge->getRelatedness("hjxlq#n", "pynbr#n"))
{
    print "not ok 6\n";
}
else
{
    ($err, $errString) = $edge->getError();
    if($err == 1)
    {
	print "ok 6\n";
    }
    else
    {
	print "not ok 6\n";
    }
}

############ Relatedness across parts of speech.

$edge->{'trace'} = 1;
if($edge->getRelatedness("object#n#1", "run#v#1") != 0)
{
    print "not ok 7\n";
}
else
{
    print "ok 7\n";
}

############ Test traces.

if($edge->getTraceString() !~ /Relatedness 0 across parts of speech/)
{
    print "not ok 8\n";
}
else
{
    print "ok 8\n";
}