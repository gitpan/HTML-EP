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

package HTML::EP::Locale;

@HTML::EP::Locale::ISA = qw(HTML::EP);

sub init ($) {
    my($self) = @_;
    if (!$self->{_ep_language}) {
	$self->SUPER::init();
	my $lang = $self->{cgi}->param('language');
	if (!$lang) {
	    if ($self->{env}->{PATH_TRANSLATED} =~ /\.(\w+)\.\w+$/) {
		$lang = $1;
	    } else {
		$lang = 'de';
	    }
	}
	$self->{_ep_language} = $lang;
	$self->{_ep_funcs}->{'ep-language'} = { method => '_ep_language',
						default => 'string' },
    }
}


sub _ep_language ($$;$) {
    my($self, $attr, $func) = @_;
    if (exists($attr->{language})) {
	if (!defined($attr->{string})) { return undef; }
	($attr->{language} eq $self->{_ep_language}) ? $attr->{string} : '';
    } else {
	exists($attr->{$self->{_ep_language}}) ?
	    $attr->{$self->{_ep_language}} : '';
    }
}

1;
