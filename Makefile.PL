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
use Getopt::Long;


use vars qw($opt_config);
Getopt::Long::GetOptions('config');


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

my $ok = 1;
$ok = 0 unless CheckModule("Data::Dumper");
$ok = 0 unless CheckModule("Storable");
$ok = 0 unless CheckModule("LWP", undef, "libwww");
$ok = 0 unless CheckModule("Mail::Internet", 1.32);
$ok = 0 unless CheckModule("URI::Escape");
$ok = 0 unless CheckModule("CGI::Cookie");

if (!$ok) {
    print <<"MESSAGE";

Missing modules are available from any CPAN mirror, for example
	ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module

MESSAGE
}

if (!$ok) {
    exit 1;
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
if (-f "lib/HTML/EP/Config.pm"  and  ! $opt_config) {
    $cfg = do "lib/HTML/EP/Config.pm";
    die $@ if $@;
} else {
    eval { require HTML::EP::Config };
    $cfg = $HTML::EP::Config::CONFIGURATION || {};

    my $email = $cfg->{'email'} || "none";
    $cfg->{'email'} =
	prompt("\nEnter an email address for sending test mails: ", $email);
    my $mailhost = $cfg->{'mailhost'} || "127.0.0.1";
    $cfg->{'mailhost'} =
	prompt("\nEnter a mail server for sending mails: ", $mailhost);
    my $debughosts = $cfg->{'debughosts'} ||
	'^(?:127\.0\.0\.1$|192\.168\.)';
    $cfg->{'debughosts'} =
        prompt("\nSecurity: Enter a regular expression for hosts that may"
               . " enter debugging\nmode: ", $debughosts);
    my $ok_templates = $cfg->{'ok_templates'} || '\.ep$';
    $cfg->{'ok_templates'} =
        prompt("\nSecurity: Enter a regular expression for files that may be"
               . " processed by\nEP: ", $ok_templates);
    my $optimization = $cfg->{'optimization'} || "n";
    $cfg->{optimization} =
 	(prompt(q[
The HTML::EP module can be optimized for fast compilation or fast startup.
The former is recommended in traditional CGI binaries, the latter for
mod_perl. Shall I optimize for fast startup, aka mod_perl? ], "y") =~ /y/) ?
        "startup" : "compilation";
    my $language = $cfg->{'default_language'} || "de";
    $cfg->{'default_language'} =
	prompt("\nEnter the default language, for example de (German) or"
	       . " en (English): ", $language);

    my $cfgdump = Data::Dumper->new([$cfg], ['CONFIGURATION']);
    $cfgdump->Indent(1);
    if (!open(FILE, ">lib/HTML/EP/Config.pm")  ||
	!(print FILE ("package HTML::EP::Config;\n", $cfgdump->Dump()))  ||
	!close(FILE)) {
	die "Cannot create config file: $!";
    }
}


my %opts = (
    'NAME'	   => 'HTML::EP',
    'VERSION_FROM' => 'lib/HTML/EP.pm',
    'EXE_FILES'    => [ 'ep.cgi' ],
    'dist'         => { 'SUFFIX'       => ".gz",
			'DIST_DEFAULT' => 'all tardist',
			'COMPRESS'     => "gzip -9vf" },
    'clean'        => { 'FILES' => 'ep.cgi' },
    'realclean'    => { 'FILES' => 'lib/HTML/EP/Config.pm' },
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
pm_to_blib: README

README: lib/HTML/EP.pod
	perldoc -t lib/HTML/EP.pod >README

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
