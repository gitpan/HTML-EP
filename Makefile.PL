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

use ExtUtils::MakeMaker qw(WriteMakefile);

sub prompt {
    my($msg, $def) = @_;
    my $dispdef = defined $def ? "[$def] " : " ";
    $def = defined $def ? $def : "";
    print "$msg $dispdef";
    my $ans = <STDIN>;
    $ans =~ s/^\s+//;
    $ans =~ s/\s+$//;
    ($ans ne '') ? $ans : $def;
}

my %prereq;
sub CheckModule ($;$$) {
    my($module, $version, $package) = @_;
    $package ||= $module;
    $prereq{$module} = $version || 0;
    if ($version) {
        print "Checking for $package, $version or later ... ";
        eval "use $module $version";
        if ($@) {
            print("\nYou don't have installed the $package package,",
                  " version $version or later.\n");
            return 0;
        }
    } else {
        print "Checking for $package ... ";
        eval "use $module";
        if ($@) {
            print("\nYou don't have installed the $package package.\n");
            return 0;
        }
    }
    print "ok\n";
    return 1;
}

if (!$ENV{CREATE_ONLY}) {
    my $ok = 1;
    $ok &&= CheckModule("Data::Dumper");
    $ok &&= CheckModule("Storable");
    $ok &&= CheckModule("LWP", undef, "libwww");
    $ok &&= CheckModule("Mail::Internet", undef, "MailTools");

    if (!$ok) {
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


my %opts = (
    'NAME'	   => 'HTML::EP',
    'VERSION_FROM' => 'lib/HTML/EP.pm',
    'EXE_FILES'    => [ 'ep.cgi' ],
    'dist'         => { 'SUFFIX'       => ".gz",
			'DIST_DEFAULT' => 'all tardist',
			'COMPRESS'     => "gzip -9f" },
    'clean'        => { 'FILES' => 'ep.cgi' },
    'realclean'    => { 'FILES' => 'configuration lib/HTML/EP.pm' },
);

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{'ABSTRACT'} = 'A system for embedding Perl into HTML';
    $opts{'AUTHOR'} = 'Jochen Wiedmann (joe@ispsoft.de)';
    $opts{'PREREQ_PM'} = \%prereq;
}

WriteMakefile(%opts);


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

sub test {
    my($self) = @_;
    my $makesrc = $self->SUPER::test();
    "test :: \$(EXE_FILES)\n\t\$(NOOP)\n\n" . $makesrc;
}
