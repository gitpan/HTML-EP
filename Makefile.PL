# -*- perl -*-
#
#   HTML::EP	- A Perl based HTML extension.
#
#
#   Copyright (C) 1998    Jochen Wiedmann
#                         Am Eisteich 9
#                         72555 Metzingen
#                         Germany
#
#                         Phone: +49 7123 14887
#                         Email: joe@ispsoft.de
#
#   All rights reserved.
#
#   You may distribute this module under the terms of either
#   the GNU General Public License or the Artistic License, as
#   specified in the Perl README file.
#
############################################################################

require 5.004;
use strict;

use ExtUtils::MakeMaker qw(prompt WriteMakefile);


if (!$ENV{CREATE_ONLY}) {
    my($ok) = 1;
    my($recommended) = 0;

    print "Checking for Data-Dumper ... ";
    $@ = '';
    eval "use Data::Dumper ();";
    if ($@) {
	$recommended = 0;
	print("\nYou don't have installed the Data-Dumper module.\n",
	      "I won't be able to test sending emails.\n");
    } else {
	print "ok\n";
    }
    
    print "Checking for HTML-Parser ... ";
    $@ = '';
    eval "use HTML::Parser ();";
    if ($@) {
	$ok = 0;
	print("\nYou don't have installed the HTML-Parser module.\n");
    } else {
	print "ok\n";
    }

    print "Checking for libwww ... ";
    $@ = '';
    eval "use LWP ();";
    if ($@) {
	$ok = 0;
	print("\nYou don't have installed the libwww modules.\n");
    } else {
	print "ok\n";
    }

    print "Checking for MailTools ... ";
    $@ = '';
    eval "use Mail::Internet ();";
    if ($@) {
	$ok = 0;
	print("\nYou don't have installed the MailTools package.\n");
    } else {
	print "ok\n";
    }


    if (!$ok  ||  $recommended) {
	print <<"MESSAGE";

Missing modules are available from any CPAN mirror, for example
	ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module

MESSAGE
    }
    
    if (!$ok) {
	exit 1;
    }
}


eval "use HTML::EP ();";
if (!$@  &&  $HTML::EP::VERSION < 0.1100) {
    print <<'MSG';

You seem to have installed a recent version of HTML::EP. There have been
important changes in the current version that may break existing code:
The "epparse-" and "epperl-" attributes have been removed. See the CHANGES
section in the manual for details. (In short all you have to do is removing
the "epperl-" and "epparse-" markers, the package ought to detect
automatically that it should parse or evaluate attributes.)

MSG
}


my $cfg = {};
my $create = exists($ENV{CREATE_ONLY});
if (-f "configuration") {
    $cfg = do "configuration";
} else {
    $cfg->{email} = prompt("Enter an email address for sending test mails: ",
			   "none");
    $cfg->{mailhost} =
	prompt("Enter a mail server for sending mails: ", "127.0.0.1");
    my $cfgdump = Data::Dumper->new([$cfg], ['CONFIGURATION']);
    if (!open(FILE, ">configuration")  ||
	!(print FILE ($cfgdump->Dump()))  ||
	!close(FILE)) {
	die "Cannot create config file: $!";
    }
    $create = 1;
}

if ($create) {
    my $ref;
    foreach $ref (['EP.pm.in', 'lib/HTML/EP.pm']) {
	printf("Creating %s from %s ... ", $ref->[1], $ref->[0]);
	if (!open(FILE, "<" . $ref->[0])) {
	    die "Cannot open " . $ref->[0] . ": $!";
	}
	my $contents;
	{ local $/; $contents = <FILE>; }
	if (!defined($contents)  ||  !close(FILE)) {
	    die "Error while reading " . $ref->[0] . ": $!";
	}
	$contents =~ s/\~(\w+)\~/$cfg->{$1}/eg;
	if (!open(FILE, ">" . $ref->[1])
	    ||  !(print FILE ($contents))
	    ||  !close(FILE)) {
	    die "Error while creating " . $ref->[1] . ": $!";
	}
	print "Ok.\n";
    }
}
    

if ($ENV{CREATE_ONLY}) { exit 0; }


WriteMakefile(
    'NAME'	   => 'HTML::EP',
    'VERSION_FROM' => 'lib/HTML/EP.pm',
    'EXE_FILES'    => [ 'ep.cgi' ],
    'dist'         => { 'SUFFIX'       => ".gz",
			'DIST_DEFAULT' => 'all tardist',
			'COMPRESS'     => "gzip -9f" },
    'clean'        => { 'FILES' => 'ep.cgi' },
    'realclean'    => { 'FILES' => 'configuration lib/HTML/EP.pm' },
);


package MY;

sub postamble {
    <<"END_OF_POSTAMBLE";
pm_to_blib: README lib/HTML/EP.pm

README: lib/HTML/EP.pod
	perldoc -t lib/HTML/EP.pod >README

lib/HTML/EP.pm: EP.pm.in
\t$^X -e '\$\$ENV{CREATE_ONLY} = 1; do "Makefile.PL"'
END_OF_POSTAMBLE
}

sub libscan {
    my($self, $path) = @_;
    if ($path =~ /\~$/) {
	undef;
    } else {
	$path;
    }
}
