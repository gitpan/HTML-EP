# -*- perl -*-

use strict;


print "1..40\n";

require HTML::EP;

my $have_dbd_csv = eval { require DBD::CSV };
my $have_dbi = eval { require DBI };


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


$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING} = '';


my $parser = HTML::EP->new();
Test($parser, "Creating the parser.\n");

my $input = <<'END_OF_HTML';
<HTML><!-- This is a comment; it will stay -->
      <ep-comment>This is another comment. It will be removed.</ep-comment>.
</HTML>
END_OF_HTML

my $output = <<'END_OF_HTML';
<HTML><!-- This is a comment; it will stay -->
      .
</HTML>
END_OF_HTML
Test2($parser->Run($input), $output, "Multi-line comment.\n");

$parser = HTML::EP->new();
$input = <<'END_OF_HTML';
<HTML><!-- This is a comment; it will stay -->
      <ep-comment comment="This is another comment. It will be removed.">.
</HTML>
END_OF_HTML
Test2($parser->Run($input), $output, "Single-line comment.\n");


$parser = HTML::EP->new();
$input = '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">';
Test2($parser->Run($input), $input, "DOCTYPE\n");


$parser = HTML::EP->new();
$input = '<HTML><ep-perl code="3+4"></HTML>';
$output = '<HTML>7</HTML>';
Test2($parser->Run($input), $output, "Single-line Perl expression.\n");


$parser = HTML::EP->new();
$input = <<'_END_OF_HTML';
<HTML><ep-perl>
'ab' . 'ce'
</ep-perl>
</HTML>
_END_OF_HTML
$output = <<'_END_OF_HTML';
<HTML>abce
</HTML>
_END_OF_HTML
Test2($parser->Run($input), $output, "Multi-line Perl expression.\n");


$input = '<ep-package name="HTML::EP::Locale" require=1>'
    . '<ep-language de="Deutsch" en="English">';
$parser = HTML::EP->new();
$parser->{env}->{PATH_TRANSLATED} = "test.de.html";
Test2($parser->Run($input), "Deutsch", "Single-line Localization.\n");
$parser = HTML::EP->new();
$parser->{env}->{PATH_TRANSLATED} = "test.en.html";
Test2($parser->Run($input), "English", "Single-line Localization.\n");
$parser = HTML::EP->new();
$parser->{env}->{PATH_TRANSLATED} = "test.no.html";
Test2($parser->Run($input), "", "Single-line Localization.\n");
$input = '<ep-package name="HTML::EP::Locale" require=1>'
    . '<ep-language language=de>Deutsch</ep-language>'
    . '<ep-language language=en>English</ep-language>';
$parser = HTML::EP->new();
$parser->{env}->{PATH_TRANSLATED} = "test.de.html";
Test2($parser->Run($input), "Deutsch", "Multi-line Localization.\n");
$parser = HTML::EP->new();
$parser->{env}->{PATH_TRANSLATED} = "test.en.html";
Test2($parser->Run($input), "English", "Multi-line Localization.\n");
$parser = HTML::EP->new();
$parser->{env}->{PATH_TRANSLATED} = "test.no.html";
Test2($parser->Run($input), "", "Multi-line Localization.\n");


if (!$have_dbi  ||  !$have_dbd_csv) {
    ++$numTests;
    print "ok $numTests # Skip\n";
} else {
    $parser = HTML::EP->new();
    $input = <<'_END_OF_HTML';
<HTML><ep-database dsn="DBI:CSV:"></HTML>
_END_OF_HTML
    $output = <<'_END_OF_HTML';
<HTML></HTML>
_END_OF_HTML
    my $got = eval { $parser->Run($input); };
    Test2($got, $output, "Making a Database connection.\n");
}
my $dbh = $parser->{dbh};


if (-f 'foo') { unlink 'foo'; }
$parser = HTML::EP->new();
$input = <<'_END_OF_HTML';
<HTML>
<ep-database dsn="DBI:CSV:">
<ep-query statement="CREATE TABLE foo (id INTEGER, name VARCHAR(64))">
<ep-query statement="INSERT INTO foo VALUES (1, 'joe')">
<ep-query statement="INSERT INTO foo VALUES (2, 'amar')">
<ep-query statement="SELECT * FROM foo" result="people">
<TABLE>
<ep-list items="people" item="p">
  <TR><TD>$p->id$</TD><TD>$p->name$</TD>
</ep-list>
</TABLE>
</HTML>
_END_OF_HTML
$output = <<'_END_OF_HTML';
<HTML>





<TABLE>

  <TR><TD>1</TD><TD>joe</TD>

  <TR><TD>2</TD><TD>amar</TD>

</TABLE>
</HTML>
_END_OF_HTML
if (!$have_dbi  ||  !$have_dbd_csv  ||  !$dbh) {
    ++$numTests;
    print "ok $numTests # Skip\n";
} else {
    Test2($parser->Run($input), $output, "SQL queries.\n");
}


$parser = HTML::EP->new();
$input = '<ep-select range="1..5" name="foo" selected=3 item=y>'
    . '<OPTION $selected$>$y$</ep-select>';
$output= '<SELECT NAME="foo"><OPTION >1<OPTION >2<OPTION SELECTED>3<OPTION >4'
    . '<OPTION >5</SELECT>';
Test2($parser->Run($input), $output, "Select lists.\n");


$ENV{QUERY_STRING} = 'address_t_name=joe&address_t_street=Am+Eisteich+9'
    . '&address_n_zip=72555&address_t_city=Metzingen'
    . '&address_dy_date1=1998&address_dm_date1=7&address_dd_date1=2'
    . '&address_dy_date2=98&address_dm_date2=7&address_dd_date2=2'
    . '&address_dy_date3=8&address_dm_date3=7&address_dd_date3=2';
$input = <<'_END_OF_HTML';
<ep-input prefix="address_" dest=address>
<HTML>
<P>Name = $address->name->val$</P>
<P>Street = $address->street->val$</P>
<P>Zip = $address->zip->val$</P>
<P>City = $address->city->val$</P>
<P>Date1 = $address->date1->val$</P>
<P>Date2 = $address->date2->val$</P>
<P>Date3 = $address->date3->val$</P>
</HTML>
_END_OF_HTML
$output = <<'_END_OF_HTML';

<HTML>
<P>Name = joe</P>
<P>Street = Am Eisteich 9</P>
<P>Zip = 72555</P>
<P>City = Metzingen</P>
<P>Date1 = 1998-07-02</P>
<P>Date2 = 1998-07-02</P>
<P>Date3 = 2008-07-02</P>
</HTML>
_END_OF_HTML
$parser = HTML::EP->new();
Test2($parser->Run($input), $output, "Object input.\n");

$ENV{QUERY_STRING} = 'art_0_t_name=Book&art_0_n_price=5.00'
    . '&art_1_t_name=Donut&art_1_n_price=1.00';
$input = <<'_END_OF_HTML';
<ep-input prefix="art_" dest=art list=1>
<ep-list items=art item=a>
  Name = $a->name->val$, Price = $a->price->val$, Item = $a->i$
</ep-list>
_END_OF_HTML
$output = <<'_END_OF_HTML';


  Name = Book, Price = 5.00, Item = 0

  Name = Donut, Price = 1.00, Item = 1

_END_OF_HTML
undef @CGI::QUERY_PARAM; # Arrgh! CGI caches :-(
$parser = HTML::EP->new();
Test2($parser->Run($input), $output, "Object list input.\n");


$input = <<'_END_OF_HTML';
<HTML>
<ep-if epperl-eval="$_->{i}==0">0<ep-elseif epperl-eval="$_->{i}==1">1<ep-elseif epperl-eval="$_->{i}==2">2<ep-else>3</ep-if>
</HTML>
_END_OF_HTML

for (my $i = 0;  $i < 4;  $i++) {
$output = <<"_END_OF_HTML";
<HTML>
$i
</HTML>
_END_OF_HTML
    $parser = HTML::EP->new();
    $parser->{i} = $i;
    Test2($parser->Run($input), $output, "If: $i.\n");
}


$input = <<'_END_OF_HTML';
<HTML>
<ep-if epperl-eval="$_->{i}<0">
    i is < 0.
<ep-elseif epperl-eval="$_->{i}==0">
    i equals 0.
<ep-elseif epperl-eval="$_->{j}<0">
    j is < 0.
<ep-elseif epperl-eval="$_->{j}==0">
    j equals 0.
<ep-else>
    Both numbers are > 0.
</ep-if>
</HTML>
_END_OF_HTML

my $ref;
my @conditionals = (
    [ -1, -1, "i is < 0." ],
    [ -1, 0,  "i is < 0." ],
    [ -1, 1,  "i is < 0." ],
    [ 0, -1,  "i equals 0." ],
    [ 0, 0,   "i equals 0." ],
    [ 0, 1,   "i equals 0." ],
    [ 1, -1,  "j is < 0." ],
    [ 1, 0,   "j equals 0." ],
    [ 1, 1,   "Both numbers are > 0." ]
);
foreach $ref (@conditionals) {
    $parser = HTML::EP->new();
    $parser->{i} = $ref->[0];
    $parser->{j} = $ref->[1];
    my $result = $ref->[2];    
    $output = <<"_END_OF_HTML";
<HTML>

    $result

</HTML>
_END_OF_HTML
    Test2($parser->Run($input), $output);
}


$input = <<'_END_OF_HTML';
<HTML>
<ep-if epperl-eval="$_->{i}<0">
    i is < 0.
<ep-elseif epperl-eval="$_->{i}==0">
    i equals 0.
<ep-else><ep-if epperl-eval="$_->{j}<0">
    j is < 0.
<ep-elseif epperl-eval="$_->{j}==0">
    j equals 0.
<ep-else>
    Both numbers are > 0.
</ep-if></ep-if>
</HTML>
_END_OF_HTML

foreach $ref (@conditionals) {
    $parser = HTML::EP->new();
    $parser->{i} = $ref->[0];
    $parser->{j} = $ref->[1];
    my $result = $ref->[2];    
    $output = <<"_END_OF_HTML";
<HTML>

    $result

</HTML>
_END_OF_HTML
    Test2($parser->Run($input), $output);
}


my $cfg;
if (-f "configuration") {
    $cfg = do "configuration";
}
if (!$cfg->{email}  ||  $cfg->{email} eq 'none'  ||  !$cfg->{mailhost}) {
    Test(1);
} else {
    print("Sending mail to ", $cfg->{email}, " via mail server ",
          $cfg->{mailhost}, "\n");
    $input = <<'_END_OF_HTML';
<HTML>
<ep-mail from="joe@ispsoft.de" epparse-to="$cgi->email$" subject="Testmail">

Hello,

this is a testmail from the script t/misc.t in the HTML::EP distribution.
You may safely ignore it. It was sent to $cgi->email$ by using the mailserver
$cgi->mailhost$.

You should be alarmed, though, if it doesn't reach you. :-)


Yours sincerely,

Jochen Wiedmann
</ep-mail>
</HTML>
_END_OF_HTML
    $output = <<'_END_OF_HTML';
<HTML>

</HTML>
_END_OF_HTML
    $ENV{QUERY_STRING} = 'email=' . URI::Escape::uri_escape($cfg->{email}) .
        '&mailhost=' . URI::Escape::uri_escape($cfg->{mailhost});
    undef @CGI::QUERY_PARAM; # Arrgh! CGI caches :-(
    $parser = HTML::EP->new();
    Test2($parser->Run($input), $output);
}


if (-f 'foo') { unlink 'foo' }

