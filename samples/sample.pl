#!/usr/local/bin/perl -w

# Sample Perl program, showing how to use the 
# WordNet::Similarity measures.

# WordNet::QueryData is required by all the
# relatedness modules.
use WordNet::QueryData;

# 'use' each module that you wish to use.
use WordNet::Similarity::jcn;
use WordNet::Similarity::res;
use WordNet::Similarity::lin;
use WordNet::Similarity::lch;
use WordNet::Similarity::hso;
use WordNet::Similarity::edge;
use WordNet::Similarity::random;
use WordNet::Similarity::lesk;

# Get the concepts.
$wps1 = shift;
$wps2 = shift;

# Load WordNet::QueryData
print STDERR "Loading WordNet... ";
$wn = WordNet::QueryData->new;
die "Unable to create WordNet object.\n" if(!$wn);
print STDERR "done.\n";


# Create an object for each of the measures of
# semantic relatedness.
print STDERR "Creating jcn object... ";
$jcn = WordNet::Similarity::jcn->new($wn);
die "Unable to create jcn object.\n" if(!defined $jcn);
($error, $errString) = $jcn->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating res object... ";
$res = WordNet::Similarity::res->new($wn);
die "Unable to create res object.\n" if(!defined $res);
($error, $errString) = $res->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating lin object... ";
$lin = WordNet::Similarity::lin->new($wn);
die "Unable to create lin object.\n" if(!defined $lin);
($error, $errString) = $lin->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating lch object... ";
$lch = WordNet::Similarity::lch->new($wn);
die "Unable to create lch object.\n" if(!defined $lch);
($error, $errString) = $lch->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating hso object... ";
$hso = WordNet::Similarity::hso->new($wn, "hso.conf");
die "Unable to create hso object.\n" if(!defined $hso);
($error, $errString) = $hso->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating edge object... ";
$edge = WordNet::Similarity::edge->new($wn);
die "Unable to create edge object.\n" if(!defined $edge);
($error, $errString) = $edge->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating random object... ";
$random = WordNet::Similarity::random->new($wn);
die "Unable to create random object.\n" if(!defined $random);
($error, $errString) = $random->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating lesk object... ";
$lesk = WordNet::Similarity::lesk->new($wn);
die "Unable to create lesk object.\n" if(!defined $lesk);
($error, $errString) = $lesk->getError();
die $errString if($error > 1);
print STDERR "done.\n";



# Find the relatedness of the concepts using each of 
# the measures.
$value = $jcn->getRelatedness($wps1, $wps2);
($error, $errString) = $jcn->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n";

$value = $res->getRelatedness($wps1, $wps2);
($error, $errString) = $res->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n";

$value = $lin->getRelatedness($wps1, $wps2);
($error, $errString) = $lin->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n";

$value = $lch->getRelatedness($wps1, $wps2);
($error, $errString) = $lch->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n";

$value = $hso->getRelatedness($wps1, $wps2);
($error, $errString) = $hso->getError();
die $errString if($error > 1);
$trace = $hso->getTraceString();

print "Similarity = $value\n";
print "ErrorString = $errString\n";
print "TRACE\n\n$trace\n";

$value = $edge->getRelatedness($wps1, $wps2);
($error, $errString) = $edge->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n";

$value = $random->getRelatedness($wps1, $wps2);
($error, $errString) = $random->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n";

$value = $lesk->getRelatedness($wps1, $wps2);
($error, $errString) = $lesk->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n";

