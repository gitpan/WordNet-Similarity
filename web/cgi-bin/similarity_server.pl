#!/usr/local/bin/perl -wT

use strict;
use POSIX ':sys_wait_h';  # for waitpid() and friends; used by reaper()

# the following three variables will need to be tweaked according
# to your installation.  BASEDIR in particular will need to be changed,
# the others might work as is.
#
# $BASEDIR is simply the directory of that where this file resides.
my $BASEDIR = '/usr/local/apache2/cgi-bin';
my $localport = 31134;
my $wnlocation = '/usr/local/WordNet-2.0/dict';


my $lock_file = "$BASEDIR/similarity_server.lock";
my $error_log = "$BASEDIR/error.log";
my $conf_file = "similarity_server.conf";

my $wordvectors = "wordvectors.dat";
my $compfile = "compfile.txt";
my $stoplist = "stoplist.txt";

my $maxchild = 4; # max number of child processes at one time

sub reaper;

if (-e $conf_file) {
    open CFH, '<', $conf_file or die "Cannot open config file $conf_file: $!";

    while (my $line = <CFH>) {
        $line =~ s/\#.*$//;
        $line =~ s/\n|\r//g;
        unless ($line =~ /(\w+)\:\:(\S+)/) {
            next unless defined $1;
        }

        if ($1 eq 'lock_file') {
            print "lock_file=$2\n";
            $lock_file = $2;
        }
        elsif ($1 eq 'error_log') {
            print "error_log=$2\n";
            $error_log = $2;
        }
	elsif ($1 eq 'vectordb') {
	    $wordvectors = $2;
	    print "vectordb=$2\n";
	}
	elsif ($1 eq 'compounds') {
	    $compfile = $2;
	    print "compounds=$2\n";
	}
	elsif ($1 eq 'stop') {
	    $stoplist = $2;
	    print "stoplist=$2\n";
	}
	elsif ($1 eq 'maxchild') {
	    $maxchild = $2;
	    print "maxchild=$2\n";
	}
        else {
            warn "Unknown config option in $conf_file at $.\n";
        }
    }

    close CFH;
}
else {
    print "No config file used\n";
}

my $lockfh;

if (-e $lock_file) {
    die "Lock file `$lock_file' already exists.  Make sure that another\n",
    "instance of $0 isn't running, then delete the lock file.\n";
}
open ($lockfh, '>', $lock_file)
    or die "Cannot open lock file `$lock_file' for writing: $!";
print $lockfh $$;
close $lockfh or die "Cannot close lock file `lock_file': $!";

END {
    if (open FH, '<', $lock_file) {
	my $pid = <FH>;
	close FH;
	unlink $lock_file if $pid eq $$;
    }
}

# prototypes:
sub getAllForms ($);
sub getlock ();
sub releaselock ();

use sigtrap handler => \&bailout, 'normal-signals';
use IO::Socket::INET;

use WordNet::QueryData;
use WordNet::Similarity::hso;
use WordNet::Similarity::jcn;
use WordNet::Similarity::lch;
use WordNet::Similarity::lesk;
use WordNet::Similarity::lin;
use WordNet::Similarity::path;
use WordNet::Similarity::random;
use WordNet::Similarity::res;
use WordNet::Similarity::vector_pairs;
use WordNet::Similarity::wup;

my $wn = WordNet::QueryData->new ($wnlocation);

$wn or die "Couldn't construct WordNet::QueryData object";

our $hso = WordNet::Similarity::hso->new ($wn);
our $jcn = WordNet::Similarity::jcn->new ($wn);
our $lch = WordNet::Similarity::lch->new ($wn);

my $leskcfg = "lesk$$.cfg";
open FH, '>', $leskcfg or die "Cannot open $leskcfg for writing: $!";
print FH "WordNet::Similarity::lesk\n";
print FH "stem::1\n";
print FH "stop::stoplist.txt\n" if -e 'stoplist.txt';
close FH;

our $lesk = WordNet::Similarity::lesk->new ($wn, $leskcfg);
unlink $leskcfg;

my $vectorcfg = "vector$$.cfg";
open VFH, '>', $vectorcfg or die "Cannot open $vectorcfg for writing: $!";
print VFH "WordNet::Similarity::vector\n";
print VFH "stop::$stoplist\n" if -e 'stoplist.txt';
print VFH "stem::1\n";
print VFH "compounds::$compfile\n";
print VFH "vectordb::$wordvectors\n";
close VFH;

our $vector = WordNet::Similarity::vector->new ($wn, $vectorcfg);
unlink $vectorcfg;


our $lin = WordNet::Similarity::lin->new ($wn);
our $path = WordNet::Similarity::path->new ($wn);
our $random = WordNet::Similarity::random->new ($wn);
our $res = WordNet::Similarity::res->new ($wn);
our $wup = WordNet::Similarity::wup->new ($wn);

my @measures = ($hso, $jcn, $lch, $lesk, $lin, $path, $random, $res, $wup, $vector);
foreach (@measures) {
    my ($err, $errstr) = $_->getError ();
    die "$errstr died" if $err;
}
undef @measures;

# reset (untaint) the PATH
$ENV{PATH} = '/bin:/usr/bin:/usr/local/bin';



# re-direct STDERR from wherever it is now to a log file
close STDERR;
open (STDERR, '>', $error_log) or die "Could not re-open STDERR";
chmod 0664, $error_log;


# The is the socket we listen to
my $socket = IO::Socket::INET->new (LocalPort => $localport,
				    Listen => SOMAXCONN,
				    Reuse => 1,
				    Type => SOCK_STREAM
				   ) or die "Could not be a server: $!";

# this variable is incremented after every fork, and is 
# updated by reaper() when a child process dies
my $num_children = 0;

## SEE BELOW
# automatically reap child processes
#$SIG{CHLD} = 'IGNORE';
##
## BETTER WAY:
# handle death of child process
$SIG{CHLD} = \&reaper;

my $interrupted = 0;

ACCEPT:
while ((my $client = $socket->accept) or $interrupted) {
    $interrupted = 0;

    next unless $client; # a SIGCHLD was raised

    # check to see if it's okay to handle this request
    if ($num_children >= $maxchild) {
	print $client "busy\015\012";
	$client->close;
	undef $client;
	next ACCEPT;
    }


    my $childpid;
    # fork; let the child handle the actual request
    if ($childpid = fork) {
	# This is the parent

	$num_children++;

	# go wait for next request
	undef $client;
	next ACCEPT;
    }

    # This is the child process

    defined $childpid or die "Could not fork: $!";

    # here we're the child, so we actually handle the request
    my @requests;
    while (my $request = <$client>) {
	last if $request eq "\015\012";
	push @requests, $request;
    }

    foreach my $i (0..$#requests) {
        my $request = $requests[$i];
	my $rnum = $i + 1;
	$request =~ m/^(\w)\b/;
	my $type = $1 || 'UNDEFINED';
	
	if ($type eq 'v') {
	    # get version information
	    my $qdver = $wn->VERSION ();
	    my $wnver = $wn->version ();
	    my $simver = $WordNet::Similarity::VERSION;
	    print $client "v WordNet $wnver\015\012";
	    print $client "v WordNet::QueryData $qdver\015\012";
	    print $client "v WordNet::Similarity $simver\015\012";
	    print $client "\015\012";
	    goto EXIT_CHILD;
	}
	elsif ($type eq 's') {
	    my (undef, $word) = split /\s+/, $request;
	    my @senses = getAllForms ($word);
	    unless (scalar @senses) {
		print $client "! $word was not found in WordNet";
		goto EXIT_CHILD;
	    }

	    getlock;
	    foreach my $wps (@senses) {
		my @synset = $wn->querySense ($wps, "syns");
		print $client "$rnum $wps ", join (" ", @synset), "\015\012";
	    }
	    releaselock;
	}
	elsif ($type eq 'g') {
	    my (undef, $word) = split /\s+/, $request;
	    my @senses = getAllForms ($word);
	    unless (scalar @senses) {
		print $client "! $word was not found in WordNet\015\012";
		goto EXIT_CHILD;
	    }
	
	    getlock;
	    foreach my $wps (@senses) {
		my ($gloss) = $wn->querySense ($wps, "glos");
		print $client "$rnum $wps ${gloss}\015\012";
	    }
	    releaselock;
	}
	elsif ($type eq 'r') {
	    my (undef, $word1, $word2, $measure, $trace, $gloss, $syns, $root)
		= split /\s+/, $request;

	    unless (defined $word1 and defined $word2) {
		print $client "! Error: undefined input words\015\012";
		sleep 2;
		goto EXIT_CHILD;
	    }

	    my $module;
	    if ($measure =~ /^(?:hso|jcn|lch|lesk|lin|path|random|res|wup|vector)$/) {
		no strict 'refs';
		$module = $$measure;
		unless (defined $module) {
		    print $client "! Error: Couldn't get reference to measure\015\012";
		    sleep 2;
		    goto EXIT_CHILD;
		}
	    }
	    else {
		print $client "! Error: no such measure $measure\015\012";
		sleep 2;
		goto EXIT_CHILD;
	    }

	    my @wps1 = getAllForms ($word1);
	    unless (scalar @wps1) {
		print $client "! $word1 was not found in WordNet\015\012";
		goto EXIT_CHILD;
	    }
	    my @wps2 = getAllForms ($word2);
	    unless (scalar @wps2) {
		print $client "! $word2 was not found in WordNet\015\012";
		goto EXIT_CHILD;
	    }

	    if ($trace eq 'yes') {
		$module->{trace} = 1;
	    }

	    $module->{rootNode} = ($root eq 'yes') ? 1 : 0;

	    if (($gloss eq 'yes') or ($syns eq 'yes')) {
		getlock;
		foreach my $wps ((@wps1, @wps2)) {
		    if ($gloss eq 'yes') {
			my ($gls) = $wn->querySense ($wps, 'glos');
			print $client "g $wps $gls\015\012";
		    }
		    if ($syns eq 'yes') {
			my @syns = $wn->querySense ($wps, 'syns');
			print $client "s ", join (" ", @syns), "\015\012";
		    }
		}
		releaselock;
	    }


	    getlock;
	    foreach my $wps1 (@wps1) {
		foreach my $wps2 (@wps2) {
		    my $score = $module->getRelatedness ($wps1, $wps2);
		    my ($err, $errstr) = $module->getError ();
		    if ($err) {
			print $client "! $errstr\015\012";
		    }
		    else {
			print $client "r $measure $wps1 $wps2 $score\015\012";
		    }
		    if ($trace eq 'yes') {
			my $tracestr = $module->getTraceString ();
			$tracestr =~ s/[\015\012]+/<CRLF>/g;
			print $client "t $tracestr\015\012";
		    }
		}
	    }
	    releaselock;

	    # reset traces to off
	    $module->{trace} = 0;
	}
	else {
	    print $client "! Bad request type `$type'\015\012";
	}
    }

    # Terminate ALL messages with CRLF (\015\012).  Do NOT use
    # \r\n (the meaning of \r and \n varies on different platforms).
    print $client "\015\012";

 EXIT_CHILD:
    $client->close;
    $socket->close;

    # don't let the child accept:
    exit;
}

$socket->close;
exit;

sub getAllForms ($)
{
    my $word = shift;

    # check if it's a type III string already:
    return $word if $word =~ m/[^#]+\#[nvar]\#\d+/;


    # it must be a type I or II, so let's get all valid forms
    getlock;
    my @forms = $wn->validForms ($word);
    releaselock;

    return () unless scalar @forms;

    my @wps_strings;

    # for each valid form, get all valid wps strings
    foreach my $form (@forms) {
	# form is a type II string
        getlock;
	my @strings = $wn->querySense ($form);
        releaselock;
	next unless scalar @strings;
	push @wps_strings, @strings;
    }

    return @wps_strings;
}


# A signal handler, good for most normal signals (esp. INT).  Mostly we just
# want to close the socket we're listening to and delete the lock file.
sub bailout
{
    my $sig = shift;
    $sig = defined $sig ? $sig : "?UNKNOWN?";
    $socket->close if defined $socket;
    print STDERR "Bailing out (SIG$sig)\n";
    releaselock;
    unlink $lock_file;
    exit 1;
}


use Fcntl qw/:flock/;

# gets a lock on $lockfh.  The return value is that of flock.
sub getlock ()
{
    open $lockfh, '>>', $lock_file
	or die "Cannot open lock file $lock_file: $!";
    flock $lockfh, LOCK_EX;
}

# releases a lock on $lockfh.  The return value is that of flock.
sub releaselock ()
{
    flock $lockfh, LOCK_UN;
    close $lockfh;
}

# sub to reap child processes (so they don't become zombies)
# also updates the num_children variable
#
# Sub was loosely inspired by an example at
# http://www.india-seo.com/perl/cookbook/ch16_20.htm
sub reaper
{
    my $moribund;
    if (my $pid = waitpid (-1, WNOHANG) > 0) {
	$num_children-- if WIFEXITED ($?);
    }
    $interrupted = 1;
    $SIG{CHLD} = \&reaper; # cursed be SysV
}

__END__

=head1 NAME

similarity_server.pl - The server for similarity.cgi

=head1 SYNOPSIS

blah

=head1 DESCRIPTION

This script implements the backend of the web interface for
WordNet::Similarity.

This script listens to a port waiting for a request form similarity.cgi or
wps.cgi.  The client script sends a message to this script as series of
queries (see QUERY FORMAT).  After all the queries, the client sends a
message containing only CRLF (carriage-return line-feed, or \015\012).

The server (this script) responds with the results (see MESSAGE FORMAT)
terminated by a message containing only CRLF.

=head3 Example:

 Client:
 g car#n#1CRLF
 CRLF

 Sever responds:
 g car#n#1 4-wheeled motor vehicle; usually propelled by an internal
 combustion engine; "he needs a car to get to work"CRLF
 CRLF

=head2 QUERY FORMAT

<CRLF> means carriage-return line-feed "\r\n" on Unix, "\n\r" on Macs,
\015\012 everywhere and anywhere (i.e., don't use \n or \r, use \015\012).

The queries consist of messages in the following formats:

 s <word1> <word2><CRLF> - server will return all senses of word1 and
 word2

 g <word><CRLF> - server will return the gloss for each synset to which
 word belongs

 r <wps1> <wps2> <measure> <etc...><CRLF> - server will return the
 relatedness of wps1 and wps2 using measure.

 v <CRLF> - get version information

=head2 MESSAGE FORMAT

The messages sent from this server will be in the following formats:

 ! <msg><CRLF> - indicates an error or warning

 g <wps> <gloss><CRLF> - the gloss of wps

 r <wps1> <wps2> <score><CRFL> - the relatedness score of wps1 and wps2

 t <msg><CRLF> - the trace output for the previous relatedness score

 s <wps1> <wps2> ... <wpsN><CRLF> - a synset

 v <package> <version number><CRLF> - the version of 'package' being used

=head1 AUTHORS

 Jason Michelizzi, University of Minnesota Duluth
 mich0212 @ d.umn.edu

 Ted Pedersen, University of Minnesota Duluth
 tpederse @ d.umn.edu

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (C) 2004, Jason Michelizzi and Ted Pedersen

This program is free software; you may redistribute and/or modify it
under the terms of the GNU General Public License version 2 or, at your
option, any later version.

=cut
