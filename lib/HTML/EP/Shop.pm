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

require HTML::EP::Session;
require HTML::EP::Locale;
require Storable;


package HTML::EP::Shop;

$HTML::EP::Shop::VERSION = '0.1001';
@HTML::EP::Shop::ISA = qw(HTML::EP::Session HTML::EP::Locale HTML::EP);


sub init {
    my $self = shift;
    if (!$self->{'_ep_language'}) {
	$self->HTML::EP::Session::init(@_);
	$self->HTML::EP::Locale::init(@_);
    }
}


sub _ep_shop_upload {
    my $self = shift; my $attr = shift;
    my $cgi = $self->{'cgi'};
    my $debug = $self->{'debug'};
    my $cgivar = $attr->{'cgivar'} || die "Missing CGI variable";
    my $dsn = $attr->{'dsn'} || "DBI:CSV:";
    if ($debug) { $self->print("Making secondary DSN: $dsn\n") }

    my $dbhf = DBI->connect($dsn, undef, undef,
			    {'RaiseError' => 1, 'Warn' => 0,
			     'PrintError' => 0});
    my $csv = Text::CSV_XS->new
	({ 'binary' => 1, 'eol' => "\r\n",
	   'sep_char' => $cgi->param('sep') || ';',
	   'quote_char' => $cgi->param('escape') || '"',
	   'escape_char' => $cgi->param('quote') || $cgi->param('escape')
	       || '"'
	       });
    $dbhf->{'csv_csv'} = $csv;

    my $table = $attr->{'table'} || die "Missing table name";
    my $fileName = $cgi->param($cgivar);
    my $tmpFile = $cgi->tmpFileName($fileName)	||  die "Missing file";
    if ($debug) {
	$self->printf("Reading table %s, file name %s, tmpfile %s.\n",
		      $table, $fileName, $tmpFile);
	$self->printf("Using separator %s, quote char %s, escape char %s\n",
		      $csv->{'sep_char'}, $csv->{'quote_char'},
		      $csv->{'escape_char'});
    }
    $dbhf->{'csv_tables'}->{$table} = {
	'file' => $tmpFile
	};
    my $query = "SELECT * FROM $table";
    if ($debug) { $self->print("SELECT query: $query\n") }
    my $sth = $dbhf->prepare($query);
    $sth->execute();

    if (my $namevar = $attr->{'names'}) {
	$self->{$namevar} = $sth->{'NAME'};
    }
    if (my $templatevar = $attr->{'template'}) {
	my $template = '';
	for (my $i = 0;  $i <= $sth->{'NUM_OF_FIELDS'};  $i++) {
	    $template .= "<TD>\$r->$i\$</TD>";
	}
	$self->{$templatevar} = $template . "\n";
	if ($self->{'debug'}) {
	    $self->print("Template = $template\n");
	}
    }
    my $numRecords = 0;

    my $dbh = $self->{'dbh'};

    $query = "DELETE FROM $table";
    if ($debug) { $self->print("Cleaning query: $query\n") }
    $dbh->do($query);

    $query = "INSERT INTO $table VALUES (";
    my $add = "";
    for (my $i = 0;  $i <= $sth->{'NUM_OF_FIELDS'};  $i++) {
	$query .= $add . "?";
	$add = ", ";
    }
    $query .= ")";
    if ($debug) { $self->print("INSERT query: $query\n") }
    my $sthi = $dbh->prepare($query);

    my @rows;
    my $result = $attr->{'result'};
    while (my $ref = $sth->fetchrow_arrayref()) {
	$sthi->execute(++$numRecords, @$ref);
	if ($result) {
	    push(@rows, [$numRecords, @$ref]);
	}
    }
    if ($result) {
	$self->{$result} = \@rows;
    }

    '';
}


sub _ep_shop_download {
    my $self = shift; my $attr = shift;
    my $cgi = $self->{'cgi'};
    my $dbh = $self->{'dbh'};
    my $table = $attr->{'table'} || die "Missing table name";
    my $csv = Text::CSV_XS->new
	({'binary' => 1,
	  'eol' => "\r\n",
	  'sep_char' => $attr->{'sep'} || ';',
	  'escape_char' => $attr->{'escape'} || '"',
	  'quote_char' => $attr->{'quote'} || $attr->{'escape'} || '"' });
    my $sth = $dbh->prepare("SELECT * FROM $table");
    $sth->execute();
    $self->print($cgi->header(-type => 'text/plain'));
    if ($self->{'debug'}) {
	$self->print("Names = ", join(", ", @{$sth->{'NAME'}}), "\n");
    }
    $csv->print($self, [@{$sth->{'NAME'}}]);
    while (my $ref = $sth->fetchrow_arrayref()) {
	$csv->print($self, $ref);
    }

    $self->Stop();
    '';
}


sub _ep_shop_prefs_read {
    my $self = shift; my $attr = shift;
    my $cgi = $self->{'cgi'};
    my $dbh = $self->{'dbh'};
    my $table = $self->{'table'} || 'prefs';
    my $prefs;
    if ($attr->{'write'}  &&  defined($cgi->{'prefs_company'})) {
	# Save Prefs
	foreach my $var ($cgi->param()) {
	    if ($var =~ /^prefs_(.*)/) {
		$prefs->{$1} = $cgi->param($var);
	    }
	}
	eval {
	    $dbh->do("UPDATE $table SET val = ? WHERE var = ?", undef,
		     Storable::nfreeze($prefs), ($attr->{'tvar'} || 'prefs'));
	};
	if ($@) {
	    $dbh->do("CREATE TABLE $table ("
		     . " var VARCHAR(32) NOT NULL,"
		     . " val BLOB NOT NULL)");
	    $dbh->do("INSERT INTO $table VALUES (?, ?)", undef,
		     ($attr->{'tvar'} || 'prefs'), Storable::nfreeze($prefs));
	}
    } else {
	# Read Prefs
	my $ref;
	eval {
	    my $sth = $dbh->prepare("SELECT val FROM prefs WHERE var = ?");
	    $sth->execute($attr->{'tvar'} || 'prefs');
	    $ref = $sth->fetchrow_arrayref();
	};
	$prefs = $ref ? Storable::thaw($ref->[0]) : {};
    }
    $self->{$attr->{'var'} || 'prefs'} = $prefs;
    '';
}


1;

__END__

=head1 NAME

  HTML::EP::Shop - An E-Commerce solution, based on HTML::EP


=head1 SYNOPSIS



=head1 DESCRIPTION



=head1 AUTHOR AND COPYRIGHT

This module is

    Copyright (C) 1998    Jochen Wiedmann
                          Am Eisteich 9
                          72555 Metzingen
                          Germany

                          Phone: +49 7123 14887
                          Email: joe@ispsoft.de

All rights reserved.

You may distribute this module under the terms of either
the GNU General Public License or the Artistic License, as
specified in the Perl README file.


=head1 SEE ALSO

L<HTML::EP(3)>, L<HTML::EP::Session> L<HTML::EP::Locale>

=cut
