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


require CGI::Cookie;


package HTML::EP::Session::Cookie;

sub new {
    my($proto, $ep, $id, $attr) = @_;
    my $class = (ref($proto) || $proto);
    my $session = {};
    bless($session, $class);
    my $freezed_session = unpack("H*", Storable::nfreeze($session));
    if ($ep->{'debug'}) {
	$ep->printf("HTML::EP::Session::Cookie: freezed session %s\n",
		    $freezed_session);
    }
    my %opts;
    $opts{'-name'} = $id;
    $opts{'-expires'} = $attr->{'expires'} || '+1h';
    $opts{'-domain'} = $attr->{'domain'} if exists($attr->{'domain'});
    $opts{'-path'} = $attr->{'path'} if exists($attr->{'path'});
    my $cookie = CGI::Cookie->new(%opts,
				  '-value' => $freezed_session);
    $ep->{'_ep_cookies'}->{$id} = $cookie;
    $session->{'_ep_data'} = \%opts;
    $session;
}

sub open {
    my($proto, $ep, $id, $attr) = @_;
    my $cgi = $ep->{'cgi'};
    my $cookie = $cgi->cookie('-name' => $id);

    return $proto->new($ep, $id, $attr) unless $cookie;

    my $class = (ref($proto) || $proto);
    my %opts;
    $opts{'-name'} = $id;
    $opts{'-expires'} = $attr->{'expires'} || '+1h';
    $opts{'-domain'} = $attr->{'domain'} if exists($attr->{'domain'});
    $opts{'-path'} = $attr->{'path'} if exists($attr->{'path'});
    if (!$cookie) {
	die "Missing cookie $id." .
	    " (Perhaps Cookies not enabled in the browser?)";
    }
    if ($ep->{'debug'}) {
	$ep->printf("HTML::EP::Session::DBI: thawing session %s\n", $cookie);
    }
    my $session = Storable::thaw(pack("H*", $cookie));
    bless($session, $class);
    $session->{'_ep_data'} = \%opts;
    $session;
}

sub store {
    my($self, $ep, $id, $locked) = @_;
    my $data = delete $self->{'_ep_data'};
    my $freezed_session = unpack("H*", Storable::nfreeze($self));
    if ($ep->{'debug'}) {
	$ep->printf("HTML::EP::Session::Cookie: freezed session %s\n",
		    $freezed_session);
    }
    my $cookie = CGI::Cookie->new(%$data,
				  '-value' => $freezed_session);
    $self->{'_ep_cookies'}->{$id} = $cookie;
    if ($locked) {
	$self->{'_ep_data'} = $data;
    }
}


sub delete {
    my($self, $ep, $id, $locked) = @_;
    my $data = delete $self->{'_ep_data'};
    my $cookie = CGI::Cookie->new('-name' => $id,
				  '-expires' => '-1m',
				  '-value' => '');
    $self->{'_ep_cookies'}->{$id} = $cookie;
}


1;
