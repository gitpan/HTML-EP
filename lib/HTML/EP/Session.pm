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
require Storable;


package HTML::EP::Session;

$HTML::EP::Session::VERSION = '0.1001';
@HTML::EP::Session::ISA = qw(HTML::EP);

sub _ep_session {
    my $self = shift; my $attr = shift;

    my $class = $attr->{'class'} || 'HTML::EP::Session::DBI';
    if ($class ne 'HTML::EP::Session::DBI') { # Builtin
	my $c = $class . '.pm';
	$c =~ s/\:\:/\//g;
	if (!$INC{$c}) { require $c }
    }

    $self->{'_ep_session_code'} = $attr->{'hex'} ? 'h' : 's';

    my $session;
    my $id = $attr->{'id'};
    if (!$id) {
	# Create a new session
	require MD5;
	my $secret = ($attr->{'secret'} || 'this is secret?');
	my $max_retries = $attr->{'max_retries'} || 5;
	for (my $i = 0;  !$session  &&  $i < $max_retries;  $i++) {
	    $id = MD5->hexhash(time() . {} . rand() . $$ . $secret);
	    $session = eval { $class->new($self, $id, $attr) };
	}
	if (!$session) { die $@ }
    } else {
	$session = $class->open($self, $id, $attr);
    }

    $self->{'_ep_session_id'} = $id;
    my $var = $attr->{'var'} || 'session';
    $self->{'_ep_session_var'} = $var;
    $self->{$var} = $session;
    if ($self->{'debug'}) {
	require Data::Dumper;
	$self->print("Created session: ", Data::Dumper::Dumper($session),
		     "\n");
    }
    '';
}

sub _ep_session_store {
    my $self = shift; my $attr = shift;

    my $id = $self->{'_ep_session_id'} || die "No session ID given";
    my $session = $self->{$self->{'_ep_session_var'}} || die "No session";
    if ($self->{'debug'}) {
	require Data::Dumper;
	$self->print("Storing session: ", Data::Dumper::Dumper($session),
		     "\n");
    }
    $session->store($self, $id, $attr->{'locked'});
    '';
}

sub _ep_session_item {
    my $self = shift; my $attr = shift;

    my $id = $self->{'_ep_session_id'} || die "No session ID given";
    my $session = $self->{$self->{'_ep_session_var'}} || die "No session";
    my $items = $session->{'items'};
    if (!$items) {
	$items = $session->{'items'} = {};
    }
    my $item = $attr->{'item'};
    my $num;
    if ($num = $attr->{'add'}) {
	$num = ($items->{$item} || 0) + $attr->{'add'};
    } else {
	$num = $attr->{'num'} || 0;
    }
    $items->{$item} = $num;
    '';
}

sub _ep_session_delete {
    my $self = shift; my $attr = shift;

    my $id = $self->{'_ep_session_id'} || die "No session ID given";
    my $session = $self->{$self->{'_ep_session_var'}} || die "No session";
    $session->delete($id);
    undef $self->{'_ep_session_id'};
    '';
}


package HTML::EP::Session::DBI;

sub new {
    my($proto, $ep, $id, $attr) = @_;
    my $class = (ref($proto) || $proto);
    my $table = $attr->{'table'} || 'sessions';
    my $dbh = $ep->{'dbh'} || die "Missing DBI dbh";
    my $session = {};
    bless($session, $class);
    my $code = $ep->{'_ep_session_code'};
    my $freezed_session = Storable::nfreeze($session);
    if ($code eq 'h') {
	$freezed_session = unpack("H*", $freezed_session);
    }
    if ($ep->{'debug'}) {
	$ep->printf("Inserting id %s, session %s\n",
		    $id, unpack("H*", $code . $freezed_session));
    }
    my $sth = $dbh->prepare("INSERT INTO $table (ID, SESSION, LOCKED)"
			    . " VALUES (?, ?, 1)");
    $sth->bind_param(1, $id, DBI::SQL_CHAR());
    $sth->bind_param(2, $code . $freezed_session, DBI::SQL_LONGVARBINARY());
    $sth->execute();
    $sth->finish();
    $session->{'_ep_data'} = { 'dbh' => $dbh,
			       'table' => $table,
			       'locked' => 1,
			       'id' => $id,
			       'code' => $code };
    $session;
}

sub open {
    my($proto, $ep, $id, $attr) = @_;
    my $class = (ref($proto) || $proto);
    my $table = $attr->{'table'} || 'sessions';
    my $dbh = $ep->{'dbh'} || die "Missing DBI dbh";
    $dbh->do("UPDATE $table SET LOCKED = 1 WHERE ID = ? AND LOCKED = 0",
	     undef, $id);
    my $sth = $dbh->prepare("SELECT SESSION FROM $table WHERE ID = ?");
    $sth->execute($id);
    my $ref = $sth->fetchrow_arrayref();
    my $freezed_session = $ref->[0];
    if ($ep->{'debug'}) {
	$ep->printf("HTML::EP::Session::DBI: freezed session %s\n",
		    unpack("H*", $freezed_session));
    }
    my $code = substr($freezed_session, 0, 1);
    $freezed_session = substr($freezed_session, 1);
    if ($code eq 'h') {
	$freezed_session = pack("H*", $freezed_session);
    }
    if ($ep->{'debug'}) {
	$ep->printf("HTML::EP::Session::DBI: thawing session %s\n",
		    unpack("H*", $freezed_session));
    }
    my $session = Storable::thaw($freezed_session);
    bless($session, $class);
    $session->{'_ep_data'} = { 'dbh' => $dbh,
			       'table' => $table,
			       'locked' => 1,
			       'id' => $id,
			       'code' => $code
			       };
    $session;
}

sub store {
    my($self, $ep, $id, $locked) = @_;
    my $data = delete $self->{'_ep_data'}  or die "No _ep_data";
    my $table = $data->{'table'} || die "No table";
    my $dbh = $data->{'dbh'};
    my $freezed_session = Storable::nfreeze($self);
    my $code = $data->{'code'};
    if ($code eq 'h') {
	$freezed_session = unpack("H*", $freezed_session);
    }
    my $sth = $dbh->prepare("UPDATE $table SET SESSION = ?"
			    . ($locked ? "" : ", LOCKED = 0")
			    . " WHERE ID = ?");
    $sth->bind_param(1, $code . $freezed_session, DBI::SQL_LONGVARBINARY());
    $sth->bind_param(2, $id, DBI::SQL_CHAR());
    $sth->execute();
    $sth->finish();
    if ($locked) {
	$self->{'_ep_data'} = $data;
    } else {
	$data->{'locked'} = 0;
    }
}

sub delete {
    my $self = shift;
    my $data = (delete $self->{'_ep_data'}) || die "No _ep_data";
    my $table = $data->{'table'} || die "No table";
    my $id = $data->{'id'};
    my $dbh = $data->{'dbh'};
    $dbh->do("DELETE FROM $table WHERE ID = ?", undef, $id);
    $data->{'locked'} = 0;
}

sub DESTROY {
    my $self = shift;
    my $data = delete $self->{'_ep_data'} || die "No _ep_data";
    if ($data->{'locked'}) {
	my $table = $data->{'table'} || die "No table";
	my $id = $data->{'id'};
	my $dbh = $data->{'dbh'};
	$dbh->do("UPDATE $table SET LOCKED = 0 WHERE ID = ?",
		 undef, $id);
    }
}


1;

__END__

=head1 NAME

  HTML::EP::Session - Session management for the HTML::EP package


=head1 SYNOPSIS

  <ep-comment>
    Create a new session or open an existing session
  </ep-comment>
  <ep-session id="$cgi->id$" var="cart">

  <ep-comment>
    Modify the session by putting an item into the shopping cart
  </ep-comment>
  <ep-perl>
    my $_ = $self; my $cart = $self->{'cart'};
    my $items = $cart->{'items'} || {};
    my $cgi = $self->{'cgi'};
    $items->{$cgi->param('item_id')} = $cgi->param('num_items');
  <ep-store

  <ep-comment>
    Same thing by using the ep-item command
  </ep-comment>
  <ep-session-item item="$cgi->item_id"
   num="$cgi->num_items">

  <ep-comment>
    Store the session
  </ep-comment>
  <ep-session-store>


=head1 DESCRIPTION

The HTML::EP::Session package is something like a little brother of
Apache::Session: Given an ID and a structured Perl variable called
the session, it stores the session into a DBI database, an external
file or whatever you prefer. For example you like to use this in
shopping carts: The shopping cart could look like this

  $session = {
    'id' => '21A32DE61A092DA1',
    'items' => { '10043-A' => 1, # 1 item of article '10043-A'
                 '10211-C' => 2  # 2 items of article '10211-C'
               }
  }

The package takes the session, converts it into a string representation by
using the I<Storable> or I<FreezeThaw> module and saves it into some
non-volatile storage space. The storage method is choosen by selecting
an appropriate subclass of HTML::EP::Session, for example
HTML::EP::Session::DBI, the default class using DBI, the database
independent Perl interface or HTML::EP::Session::File for using flat
files.


=head2 Creating or opening a session

  <ep-session class="HTML::EP::Session::DBI" table="sessions"
              var=session id="$@cgi->id$" hex=0>

If the attribute I<id> is empty or not set, this will create a new and
empty session for you. Otherwise the existing session with the given
I<id> will be opened.

By default the session will have I<class> B<HTML::EP::Session::DBI>
and data will be stored in the I<table> B<sessions>, but you can
choose another subclass of B<HTML::EP::Session> for saving data.
The session is stored in the I<session> variable of the object, but
that is overridable with the I<var> attribute.

Some storage systems don't support NUL bytes. The I<hex> attribute
forces conversion of session strings into hex strings, if set to on.
The default is off.


=head2 Storing the session

  <ep-session-store locked=0>

This stores the session back into the non-volatile storage. By default
the session is unlocked at the same time and must not be modified in
what follows, unless you set the optional I<locked> attribute to a
true value.


=head2 Managing a shopping cart

As a helper for shopping carts you might use the following command:

  <ep-session-item item="$cgi->item$" num="$cgi->num$">

This command uses a hash ref I<items> in the shopping cart, the hash
will be created automatically. The value I<num> is stored in the hashs
key I<item>. Alternatively you might use

  <ep-session-item item="$cgi->item$" add="$cgi->num$">

which is very much the same, but the item is incremented by I<add>.


=head2 Deleting a session

You can delete an existing session with

  <ep-session-delete>


=head1 LOCKING CONSIDERATIONS

All subclasses have to implement a locking scheme. To keep this scheme
clean and simple, the following rules must be applied:

=over 8

=item 1.)

First of all, acquire the resources that the respective subclass needs.
In the case of the DBI subclass this means that you have to execute the
I<ep-database> command.

=item 2.)

Next you create or open the session.

=item 3.)

If required, do any modifications and call I<ep-session-store> or
I<ep-session-delete>.

=item 4.)

Once you have called I<ep-session-store> or I<ep-session-delete>, you
most not use any more ep-session commands.

=back


=head1 SUBCLASS INTERFACE

Subclasses of HTML::EP::Session must implement the following methods:

=over 8

=item new($ep, $id, \%attr)

(Class method) This constructor creates a new session with id B<$id>.
The constructor should configure itself by using the EP object B<$ep>
and the attribute hash ref \%attr.

=item open($ep, $id, \%attr)

(Class method) This constructor must open an existing session.

=item store($ep, $id, $locked)

(Instance method) Stores the session. The B<$locked> argument advices
to keep the session locked (TRUE) or unlocked (FALSE).

=back

Error handling in subclasses is simple: All you need to do is throwing
a Perl exception. If subclasses need to maintain own data, they should
store it in $ep->{'_ep_session_data'}. The id is stored in
$ep->{'_ep_session_id'}.


=head2 The DBI subclass

This class is using the DBI (Database independent Perl interface), sessions
are stored in a table. The table name is given by the I<table> attribute
and defaults to I<sessions>. The table structure is like

  CREATE TABLE SESSIONS (
      ID INTEGER NOT NULL PRIMARY KEY,
      SESSION LONGVARCHAR,
      ACCESSED TIMESTAMP,
      LOCKED INTEGER
  )

in particular the I<SESSION> column must be sufficiently large. I suggest
using something like up to 65535, for example I am using I<SHORT BLOB>
with MySQL.

The SESSION column must accept binary characters, in particular NUL bytes.
If it doesn't, you need to replace the I<Storable> package with I<FreezeThaw>.
L<Storable(3)>. L<FreezeThaw(3)>.


=head2 The Cookie subclass

This class is using Cookies, as introduced by Netscape 2. When using
Cookies for the session, you have to use a slightly different syntax:

  <ep-session class="HTML::EP::Session::DBI" name="sessions"
              var=session id="$@cgi->id$" expires="+1h"
              domain="www.company.com" path="/"
              zlib=0 base64=0>

The attribute I<name> is the cookie's name. (Cookies are name/value
pairs.) The optional attributes I<expires>, I<domain> and I<path>
are referring to the respective attributes of CG::Cookie->new().
L<CGI::Cookie(3)>.

Cookies are unfortunately restricted to a certain size, about 4096
bytes. If your session is getting too large, you might try to reduce
the cookie size by using the Compress::Zlib and/or MIME::Base64
module. This is enabled by adding the parameters I<zlib=1> and/or
I<base64=1>.


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

L<HTML::EP(3)>, L<Apache::Session(3)>, L<DBI(3)>, L<Storable(3)>,
L<FreezeThaw(3)>, L<CGI::Cookie(3)>

=cut
