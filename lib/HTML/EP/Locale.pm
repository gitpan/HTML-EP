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

require HTML::EP;


package HTML::EP::Locale;

@HTML::EP::Locale::ISA = qw(HTML::EP);


sub init ($) {
    my $self = shift;
    return if $self->{'_ep_language'};
    $self->SUPER::init();
    $self->{_ep_language} = $self->{cgi}->param('language')  ||
	(($self->{env}->{PATH_TRANSLATED} =~ /\.(\w+)\.\w+$/) ?
	 $1 : $self->{'_ep_config'}->{'default_language'});
}


sub _ep_language ($$;$) {
    my($self, $attr, $func) = @_;
    my $language = $self->{'_ep_language'};
    my $debug = $self->{'debug'};
    if (my $lang = $attr->{'language'}) {
	my $state = ($lang eq $language);
	if (!defined($attr->{'string'})) {
	    my $stack = $self->{_ep_stack};
	    if (@$stack) {
		my $pop = $stack->[$#$stack];
		if ($pop->{'tag'} eq 'ep-language') {
		    $self->{'_ep_language_output'} .= $self->{'_ep_output'}
			if $self->{'_ep_state'};
		    $self->{'_ep_state'} = $state;
		    $self->print("ep-else-language: state = $state\n")
			if $debug;
		    $pop->{'attr'}->{'language'} = $lang;
		    return ($self->{'_ep_output'} = '');
		}
	    }
	    $self->{'_ep_state'} = $state;
	    $self->{'_ep_language_output'} = '';
	    $func->{'default'} ||= 'string';
	    $func->{'always'} ||= 1;
	    $self->print("ep-language: state = $state\n")
		if $debug;
	    return undef;
	}
	$self->printf("/ep-language: output = %s\n",
		      $self->{'_ep_language_output'} .
		      ($state ? $attr->{'string'} : ''))
	    if $debug;
	$self->{'_ep_language_output'} .
	    ($state ? $attr->{'string'} : '');
    } else {
	exists($attr->{$language}) ? $attr->{$language} : '';
    }
}


sub _format_DM {
    my $self = shift; my $str = shift;
    $str = sprintf("%.2f DM", $str);
    while ($str =~ s/(\d)(\d\d\d[\.\s])/$1 $2/) {
    }
    $str =~ s/\./,/;
    $str;
}


$HTML::EP::Locale::AUTOLOADED_ROUTINES = <<'AUTOLOADED_ROUTINES';

(

'_format_TIME' => <<'_end_of_format_TIME',
sub _format_TIME {
    my $self = shift;  my $date = shift;
    if ($self->{'_ep_language'} eq 'de') {
	              # Sun, 7 Feb 1999 18:17:57 +0100
	if ($date =~ m{(\S+),\s+
                            (\d+)\s+
                               (\S+)\s+
                                   (\d+)\s+
                                        (\d+\:\d+\:\d+)\s+
                                                 (\+\d+)}x) {
	    my %wdays = ('sun' => 0, 'mon' => 1, 'tue' => 2,
			 'wed' => 3, 'thu' => 4, 'fri' => 5,
			 'sat' => 6);
	    my $wday = (('Sonntag', 'Montag', 'Dienstag', 'Mittwoch',
			 'Donnerstag', 'Freitag', 'Samstag')[$wdays{lc $1}]);
	    my %months = ('jan' => 0, 'feb' => 1, 'mar' => 2,
			  'apr' => 3, 'may' => 4, 'jun' => 5,
			  'jul' => 6, 'aug' => 7, 'sep' => 8,
			  'oct' => 9, 'nov' => 10, 'dec' => 12
			 );
	    my $mon = (('Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
			'Juli', 'August', 'September', 'Oktober', 'November',
			'Dezember')[$months{lc $3}]);
	    $date = "$wday, den $2. $mon $4, $5 Uhr ($6)";
	}
    }
    $date;
}
_end_of_format_TIME

)

AUTOLOADED_ROUTINES

1;
