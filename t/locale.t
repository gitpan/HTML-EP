# -*- perl -*-
#
# $Id: locale.t,v 1.1 1999/02/07 20:02:38 joe Exp $
#

use strict;
use Getopt::Long ();
use HTML::EP ();

$^W = 1;
$| = 1;


print "1..13\n";


use vars qw($opt_debug);
Getopt::Long::GetOptions('debug');

my $numTests = 0;
sub Test($;@) {
    my $result = shift;
    if (@_ > 0) { printf(@_); }
    ++$numTests;
    if (!$result) { print "not " };
    print "ok $numTests\n";
    $result;
}

sub Test2($$;@) {
    my $a = shift;
    my $b = shift;
    my $c = ($a eq $b);
    if (!Test($c, @_)) {
	print("Expected $b, got $a\n");
    }
    $c;
}


$ENV{'REQUEST_METHOD'} = 'GET';
$ENV{'QUERY_STRING'} = $opt_debug ? 'debug=1' : '';


my $input = '<ep-package name="HTML::EP::Locale">'
    . '<ep-language de="Deutsch" en="English">';
my $parser = HTML::EP->new({'debug' => $opt_debug});
$parser->{env}->{PATH_TRANSLATED} = "test.de.html";
Test2($parser->Run($input), "Deutsch", "Single-line Localization.\n");
$parser = HTML::EP->new({'debug' => $opt_debug});
$parser->{env}->{PATH_TRANSLATED} = "test.en.html";
Test2($parser->Run($input), "English", "Single-line Localization.\n");
$parser = HTML::EP->new({'debug' => $opt_debug});
$parser->{env}->{PATH_TRANSLATED} = "test.no.html";
Test2($parser->Run($input), "", "Single-line Localization.\n");

$input = '<ep-package name="HTML::EP::Locale">'
    . '<ep-language language=de>Deutsch</ep-language>'
    . '<ep-language language=en>English</ep-language>';
$parser = HTML::EP->new({'debug' => $opt_debug});
$parser->{env}->{PATH_TRANSLATED} = "test.de.html";
Test2($parser->Run($input), "Deutsch", "Multi-line Localization.\n");

$parser = HTML::EP->new({'debug' => $opt_debug});
$parser->{env}->{PATH_TRANSLATED} = "test.en.html";
Test2($parser->Run($input), "English", "Multi-line Localization.\n");

$parser = HTML::EP->new({'debug' => $opt_debug});
$parser->{env}->{PATH_TRANSLATED} = "test.no.html";
Test2($parser->Run($input), "", "Multi-line Localization.\n");

$input = '<ep-package name="HTML::EP::Locale">'
    . '<ep-language language=de>Deutsch'
    . '<ep-language language=en>English</ep-language>';
$parser = HTML::EP->new({'debug' => $opt_debug});
$parser->{env}->{PATH_TRANSLATED} = "test.de.html";
Test2($parser->Run($input), "Deutsch", "Multi-line Localization.\n");

$parser = HTML::EP->new({'debug' => $opt_debug});
$parser->{env}->{PATH_TRANSLATED} = "test.en.html";
Test2($parser->Run($input), "English", "Multi-line Localization.\n");

$parser = HTML::EP->new({'debug' => $opt_debug});
$parser->{env}->{PATH_TRANSLATED} = "test.no.html";
Test2($parser->Run($input), "", "Multi-line Localization.\n");


$input = '$&DM->a$ and $&Dollar->b$';
my $output = '34,50 DM and 27.10 $';
$parser = HTML::EP->new();
$parser->{'_ep_custom_formats'}->{'DM'} = sub {
    my($self, $var) = @_;
    $var = sprintf("%.2f DM", $var);
    $var =~ s/\./,/;
    $var;
};
$parser->{'_ep_custom_formats'}->{'Dollar'} = sub {
    my($self, $var) = @_;
    sprintf("%.2f \$", $var);
};
$parser->{'a'} = 34.5;
$parser->{'b'} = 27.1;
Test2($parser->Run($input), $output, "Custom formatting\n");

$input = '<ep-package name="HTML::EP::Locale">$&DM->a$ and $&DM->b$';
$output = '1 234 567,50 DM and 273 682,00 DM';
$parser = HTML::EP->new();
$parser->{'a'} = 1234567.5;
$parser->{'b'} = 273682;
$parser->{'env'} = { 'PATH_TRANSLATED' => '' };
Test2($parser->Run($input), $output, "Locale's custom formatting\n");


$input = '<ep-package name="HTML::EP::Locale">$&TIME->date$';
$parser = HTML::EP->new();
$parser->{'date'} = 'Sun, 7 Feb 1999 18:17:57 +0100';
$parser->{env}->{PATH_TRANSLATED} = "test.de.html";
Test2($parser->Run($input),
      "Sonntag, den 7. Februar 1999, 18:17:57 Uhr (+0100)");
$parser = HTML::EP->new();
$parser->{'date'} = 'Sun, 7 Feb 1999 18:17:57 +0100';
$parser->{env}->{PATH_TRANSLATED} = "test.en.html";
Test2($parser->Run($input), 'Sun, 7 Feb 1999 18:17:57 +0100');
