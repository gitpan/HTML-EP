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

require URI::Escape;
require HTML::Entities;
require CGI;
require Symbol;
require HTML::EP::Config;


package HTML::EP;

$HTML::EP::VERSION = '0.1117';


%HTML::EP::BUILTIN_FORMATS = (
    'NBSP' => sub {
	my $self = shift; my $str = shift;
	if (!defined($str)  ||  $str eq '') {
	    $str = '&nbsp;';
	}
	$str;
    }
);

%HTML::EP::BUILTIN_METHODS = (
    'ep-comment' =>    { method => '_ep_comment',
			 default => 'comment',
		         always => 1 },
    'ep-perl' =>       { method => '_ep_perl',
			 default => 'code' },
    'ep-errhandler' => { method => '_ep_errhandler',
			 default => 'template' },
    'ep-error' =>      { method => '_ep_error',
			 default => 'msg' },
    'ep-query' =>      { method => '_ep_query',
			 default => 'statement' },
    'ep-list' =>       { method => '_ep_list',
			 default => 'template' },
    'ep-select' =>     { method => '_ep_select',
                         default => 'template' },
    'ep-if' =>         { method => '_ep_if',
			 default => 'result',
		         always => 1 },
    'ep-elseif' =>     { method => '_ep_elseif',
			 default => 'result',
			 condition => 1,
		         always => 1 },
    'ep-else' =>       { method => '_ep_elseif',
			 default => 'result',
			 condition => 0,
		         always => 1 },
    'ep-mail' =>       { method => '_ep_mail',
			 default => 'body' }
);


sub WarnHandler {
    my $msg = shift;
    if (!defined($^S)) {
	die $msg;
    }
    print STDERR $msg;
    if ($msg !~ /\n$/) {
	print STDERR "\n";
    }
}


sub new ($;$) {
    my($proto, $attr) = @_;
    my $self = $attr ? {%$attr} : {};
    $self->{'_ep_stack'} = [];
    $self->{'_ep_cookies'} ||= {};
    $self->{'_ep_funcs'} ||= { %HTML::EP::BUILTIN_METHODS };
    $self->{'_ep_custom_formats'} ||= { %HTML::EP::BUILTIN_FORMATS };
    $self->{'_ep_output'} = '';
    $self->{'_ep_state'} = 1;
    $self->{'_ep_buf'} = '';
    $self->{'_ep_strict_comment'} = 0;
    $self->{'_ep_config'} = $HTML::EP::Config::CONFIGURATION;

    if (!($self->{'cgi'} ||= CGI->new())) {
	die "Cannot create CGI object: $!";
    }
    bless($self, (ref($proto) || $proto));
    $self;
}

sub DESTROY {
    my $self = shift;
    my $dbh = $self->{'dbh'};
    undef %$self; # Force calling destructors, except for dbh
                  # dbh destructor is called later
}

sub print ($;@) {
    my $self = shift;
    if ($self->{_ep_r}) {
	$self->{_ep_r}->print(@_);
    } else {
	print @_;
    }
}
sub printf($$;@) {
    my($self, $format, @args) = @_;
    $self->print(sprintf($format, @args));
}

sub ParseVar ($$$$) {
    my($self, $type, $var, $subvar) = @_;
    my$result;
    my $func;

    if ($type  &&  $type eq '&') {
	# Custom format
	if (!($func = $self->{'_ep_custom_formats'}->{$var})) {
	    die "No such custom format: $var";
	}
	# First part of subvar becomes var
	if ($subvar  &&  $subvar =~ /^\-\>(\w+)(.*)/) {
	    $var = $1;
	    $subvar = $2;
	} else {
	    $var = '';
	}
    }

    if ($var eq 'cgi') {
	$subvar =~ s/\-\>//;
	$var = $self->{cgi}->param($subvar);
    } else {
	$var = $self->{$var};
	while ($subvar  &&  $subvar =~ /^\-\>(\w+)(.*)/) {
	    if (!ref($var)) {
		$var = '';
		last;
	    }
	    my $v = $1;
	    $subvar = $2;
	    if ($v =~ /^\d+$/) {
		$var = $var->[$v];
	    } else {
		$var = $var->{$v};
	    }
	}
    }
    if (!defined($var)) { $var = ''; }

    if (!$type  ||  $type eq '%') {
	$var = HTML::Entities::encode($var);
    } elsif ($type eq '#') {
	$var = URI::Escape::uri_escape($var);
    } elsif ($type eq '~') {
	if (!$self->{dbh}) { die "Not connected"; }
	$var = $self->{dbh}->quote($var);
    } elsif ($func) {
	$var = &$func($self, $var);
    }

    $var;
}

sub ParseVars ($$) {
    my($self, $str) = @_;
    $str =~ s{\$([\&\@\#\~\%]?)(\w+)((\-\>\w+)*)\$}
             {$self->ParseVar($1, $2, $3)}eg;
    $str;
}

sub parse
{
    my $self = shift;
    my $buf = \ $self->{'_ep_buf'};
    unless (defined $_[0]) {
	# signals EOF (assume rest is plain text)
	$self->text($$buf) if length $$buf;
	$$buf = '';
	return $self;
    }
    $$buf .= $_[0];
    my $netscape_comment = !$self->{'_ep_strict_comment'};

    # Parse html text in $$buf.  The strategy is to remove complete
    # tokens from the beginning of $$buf until we can't deside whether
    # it is a token or not, or the $$buf is empty.

  TOKEN:
    while (1) {

	# First we try to pull off any plain text (anything before a "<" char)
	if ($$buf =~ s|^([^<]+)||) {
	    if (length $$buf) {
		$self->text($1);
	    } else {
		my $text = $1;
		# At the end of the buffer, we should not parse white space
		# but leave it for parsing on the next round.
		if ($text =~ s|(\s+)$||) {
		    $$buf = $1;
                # Same treatment for chopped up entites and words.
		# We must wait until we have it all.
		} elsif ($text =~ s|(\S+)$||) {
		    $$buf = $1;
		};
		$self->text($text) if length $text;
		last TOKEN;
	    }

	# Netscapes buggy comments are easy to handle
	} elsif ($netscape_comment && $$buf =~ m|^<!--|) {
	    if ($$buf =~ s|^<!--(.*?)-->||s) {
		$self->comment($1);
	    } else {
		last TOKEN;  # must wait until we see the end of it
	    }

	# Then, markup declarations (usually either <!DOCTYPE...> or a comment)
	} elsif ($$buf =~ s|^(<!)||) {
	    my $eaten = $1;
	    my $text = '';
	    my @com = ();  # keeps comments until we have seen the end
	    # Eat text and beginning of comment
	    while ($$buf =~ s|^(([^>]*?)--)||) {
		$eaten .= $1;
		$text .= $2;
		# Look for end of comment
		if ($$buf =~ s|^((.*?)--)||s) {
		    $eaten .= $1;
		    push(@com, $2);
		} else {
		    # Need more data to get all comment text.
		    $$buf = $eaten . $$buf;
		    last TOKEN;
		}
	    }
	    # Can we finish the tag
	    if ($$buf =~ s|^([^>]*)>||) {
		$text .= $1;
		$self->declaration($text) if $text =~ /\S/;
		# then tell about all the comments we found
		for (@com) { $self->comment($_); }
	    } else {
		$$buf = $eaten . $$buf;  # must start with it all next time
		last TOKEN;
	    }

        # Should we look for 'processing instructions' <? ...> ??
	#} elsif ($$buf =~ s|<\?||) {
	    # ...

	# Then, look for a end tag
	} elsif ($$buf =~ s|^</||) {
	    # end tag
	    if ($$buf =~ s|^([a-zA-Z][a-zA-Z0-9\.\-]*)(\s*>)||) {
		my $tag = lc $1;
		my $text = "</$1$2";
		if ($tag =~ /^ep\-/) {
		    $self->end($tag, $text);
		} else {
		    $self->text($text);
		}
	    } elsif ($$buf =~ m|^[a-zA-Z]*[a-zA-Z0-9\.\-]*\s*$|) {
		$$buf = "</" . $$buf;  # need more data to be sure
		last TOKEN;
	    } else {
		# it is plain text after all
		$self->text("</");
	    }

	} elsif ($$buf =~ s|^<||) {
	    # start tag
	    my $eaten = '<';

	    # This first thing we must find is a tag name.  RFC1866 says:
	    #   A name consists of a letter followed by letters,
	    #   digits, periods, or hyphens. The length of a name is
	    #   limited to 72 characters by the `NAMELEN' parameter in
	    #   the SGML declaration for HTML, 9.5, "SGML Declaration
	    #   for HTML".  In a start-tag, the element name must
	    #   immediately follow the tag open delimiter `<'.
	    if ($$buf =~ s|^(([a-zA-Z][a-zA-Z0-9\.\-]*)\s*)||) {
		$eaten .= $1;
		my $tag = (lc $2);
		my %attr;
		my @attrseq;

		if ($tag !~ /^ep\-/) {
		    $tag = undef;
		}

		# Then we would like to find some attributes
                #
                # Arrgh!! Since stupid Netscape violates RCF1866 by
                # using "_" in attribute names (like "ADD_DATE") of
                # their bookmarks.html, we allow this too.
		while ($$buf =~ s|^(([a-zA-Z][a-zA-Z0-9\.\-_]*)\s*)||) {
		    $eaten .= $1;
		    my $attr = lc $2;
		    my $val;
		    # The attribute might take an optional value (first we
		    # check for an unquoted value)
		    if ($$buf =~ s|(^=\s*([^\"\'>\s][^>\s]*)\s*)||) {
			$eaten .= $1;
			if (defined($tag)) {
			    $val = $2;
			    HTML::Entities::decode($val);
			}
		    # or quoted by " or '
		    } elsif ($$buf =~ s|(^=\s*([\"\'])(.*?)\2\s*)||s) {
			$eaten .= $1;
			if (defined($tag)) {
			    $val = $3;
			    HTML::Entities::decode($val);
			}
                    # truncated just after the '=' or inside the attribute
		    } elsif ($$buf =~ m|^(=\s*)$| or
			     $$buf =~ m|^(=\s*[\"\'].*)|s) {
			$$buf = "$eaten$1";
			last TOKEN;
		    } else {
			# assume attribute with implicit value
			$val = $attr;
		    }
		    if (defined($tag)) {
			$attr{$attr} = $val;
			push(@attrseq, $attr);
		    }
		}

		# At the end there should be a closing ">"
		if ($$buf =~ s|^>||) {
		    if (defined($tag)) {
			$self->start($tag, \%attr, \@attrseq, "$eaten>");
		    } else {
			$self->text("$eaten>");
		    }
		} elsif (length $$buf) {
		    # Not a conforming start tag, regard it as normal text
		    $self->text($eaten);
		} else {
		    $$buf = $eaten;  # need more data to know
		    last TOKEN;
		}

	    } elsif (length $$buf) {
		$self->text($eaten);
	    } else {
		$$buf = $eaten . $$buf;  # need more data to parse
		last TOKEN;
	    }

	} else {
	    #die if length($$buf);  # This should never happen
	    last TOKEN; 	    # The buffer should be empty now
	}
    }

    $self;
}


sub eof
{
    shift->parse(undef);
}


sub parse_file
{
    my($self, $file) = @_;
    no strict 'refs';  # so that a symbol ref as $file works
    local(*F);
    unless (ref($file) || $file =~ /^\*[\w:]+$/) {
	# Assume $file is a filename
	open(F, $file) || die "Can't open $file: $!";
	$file = \*F;
    }
    my $chunk = '';
    while(read($file, $chunk, 512)) {
	$self->parse($chunk);
    }
    close($file);
    $self->eof;
}


sub Run ($;$) {
    my($self, $template) = @_;
    if ($template) {
	$self->parse($template);
	$self->eof();
    } else {
	if (!exists($self->{'env'})) {
	    if ($self->{'_ep_r'}) {
		$self->{'env'} = { $self->{_ep_r}->cgi_env() };
	    } else {
		$self->{'env'} = \%ENV;
	    }
	}
	my $file = $self->{env}->{PATH_TRANSLATED};
	if (!defined($file)) {
	    die "Missing server environment. (No PATH_TRANSLATED variable)";
	}
	my $fh = Symbol::gensym();
	if (!open($fh, "<$file")) {
	    die "Cannot open $file: $!";
	}
	$self->parse_file($fh);
	$self->eof();
    }
    $self->ParseVars($self->{_ep_output});
}


sub text ($$) {
    my($self, $text) = @_;
    $self->{_ep_output} .= $text;
}
sub comment ($$) {
    my($self, $msg) = @_;
    $self->{_ep_output} .= "<!--${msg}-->";
}
sub declaration ($$) {
    my($self, $decl) = @_;
    $self->{_ep_output} .= "<!${decl}>";
}

sub start ($$$$$) {
    my($self, $tag, $attr, $attrseq, $text) = @_;
    if ($tag =~ /^ep\-/) {
	my $func = $self->{_ep_funcs}->{$tag};
	if (!$func) {
	    my $method = $tag;
	    $method =~ s/\-/_/g;
	    $func = $self->{_ep_funcs}->{$tag} = { 'method' => "_$method" };
	}
	if (!$self->{_ep_state}  &&  !$func->{always}) {
	    return;
	}

	my($var, $val);
	while (($var, $val) = each %$attr) {
	    if ($val =~ /\$\_\W/) {
		$_ = $self;
		$attr->{$var} = eval $val;
		if ($@) { die $@ };
	    } elsif ($val =~ /\$/) {
		$attr->{$var} = $self->ParseVars($val);
	    }
	}

	my $method = $func->{method};
	my $state = $self->{_ep_state};
	if ($tag eq 'ep-if') {
	    undef $text;
	    $self->{_ep_state} = $attr->{'eval'}  &&  $state;
	    if ($self->{debug}) {
		$self->print("ep-if: Eval = '",
			     (defined($attr->{'eval'}) ? $attr->{'eval'} : ''),
			     "' changing state to ",
			     ($self->{_ep_state} ? 1 : 0), "\n");
	    }
	} else {
	    $text = $self->$method($attr, $func);
	}
	if (!defined($text)) {
	    # Multiline mode
	    my $pop = { attr => $attr,
			tag => $tag,
			output => $self->{_ep_output},
			current => ($attr->{'eval'} ? 1 : 0),
			result => undef,
			state => $state
		      };
	    push(@{$self->{_ep_stack}}, $pop);
	    $self->{_ep_output} = '';
	    return;
	}
    }
    $self->{_ep_output} .= $text;
}

sub end ($$$) {
    my($self, $tag, $text) = @_;
    if ($tag =~ /^ep\-/) {
	my $func = $self->{_ep_funcs}->{$tag};
	if (!$func) {
	    die "No such function: $tag";
	}
	if (!$self->{_ep_state}  &&  !$func->{always}) {
	    return;
	}
	my $pop;
	if (!($pop = pop(@{$self->{_ep_stack}}))  ||  $pop->{tag} ne $tag) {
	    die "/$tag without $tag";
	}

	if ($tag eq 'ep-if') {
	    if ($pop->{current}) {
		$text = $self->{_ep_output};
	    } elsif (!defined($text = $pop->{result})) {
		$text = '';
	    }
	    $self->{_ep_output} = $pop->{output};
	} else {
	    my $method = $func->{method};
	    my $attr = $pop->{attr};
	    $attr->{$func->{default}} = $self->{_ep_output};
	    $self->{_ep_output} = $pop->{output};
	    $text = $self->$method($attr, $func);
	}
	$self->{_ep_output} .= $text;
	$self->{_ep_state} = $pop->{state};
    } elsif ($self->{_ep_state}) {
	$self->{_ep_output} .= $text;
    }
}

sub init { 1 }

sub Stop ($) { my($self) = @_; $self->{_ep_stop} = 1; }


use vars qw($AUTOLOAD $AUTOLOADED_ROUTINES %AUTOLOADED_SUBS);
sub AUTOLOAD {
    my($class, $func);
    if ($AUTOLOAD =~ /(.*)\:\:(.*)/) {
	$class = $1;
	$func = $2;
    } else {
	return undef;
    }
    no strict 'refs';
    my(@isa) = ($class, @{"${class}::ISA"});
    while ($class = shift @isa) {
	my $subs = "${class}::AUTOLOADED_SUBS";
	if (!%$subs) {
	    my $subs_str = "${class}::AUTOLOADED_ROUTINES";
	    if ($$subs_str) {
		%$subs = eval $$subs_str;
		if ($@) {
		    die $@;
		}
	    }
	}
	if (exists($$subs{$func})) {
	    eval "package $class; " . $$subs{$func};
	    if ($@) {
		die $@;
	    }
            goto &{"${class}::$func"};
        }
    }
    die "Method $func is not available.";
}


############################################################################
#
#   Autoloaded functions
#
############################################################################

$AUTOLOADED_ROUTINES = <<'END_OF_AUTOLOADED_ROUTINES';

(

_ep_comment => <<'end_of__ep_comment',
sub _ep_comment ($$;$) {
    my($self, $attr) = @_;
    if (!defined($attr->{'comment'})) {
	$self->{_ep_state} = 0;
	return undef;
    }
    ''
}
end_of__ep_comment


_ep_package => <<'end_of__ep_package',
sub _ep_package ($$;$) {
    my $self = shift; my $attr = shift;
    my $package = $attr->{name};
    bless($self, $package);
    if ($attr->{'isa'}) {
	no strict 'refs';
	@{$package."::ISA"} = split(',', $attr->{'isa'});
    }
    if (!exists($attr->{'require'})  ||  $attr->{'require'}) {
	my @inc = @INC;
	if ($attr->{'lib'}) {
	    unshift(@inc, $ENV{'DOCUMENT_ROOT'} . $attr->{'lib'},
		    $attr->{'lib'});
	}
	local @INC = @inc;
	$package =~ s/\:\:/\//g;
	require $package . ".pm";
    }
    $self->init($attr);
    '';
}
end_of__ep_package

_ep_perl => <<'end_of__ep_perl',
sub _ep_perl ($$;$) {
    my $self = shift; my $attr = shift;
    my($file, $code);
    if ($file = $attr->{src}) {
	my $fh = Symbol::gensym();
	if (! -f $file  &&  -f ($self->{env}->{DOCUMENT_ROOT} . $file)) {
	    $file = ($self->{env}->{DOCUMENT_ROOT} . $file);
	}
	if (!open($fh, "<$file")) {
	    die "Cannot open $file: $!";
	}
	local $/ = undef;
	$code = <$fh>;
	if (!defined($fh)  ||  !close($fh)) {
	    die "Error while reading $file: $!";
	}
    } else {
	$code = $attr->{code};
	if (!defined($code)) {
	    return undef;
	}
    }
    my $output;
    if ($attr->{'safe'}) {
	my $compartment = $self->{_ep_compartment};
	if (!$compartment) {
	    require Safe;
	    $compartment = $self->{_ep_compartment} = Safe->new();
	}
	if ($self->{debug}) {
	    $self->print("Evaluating in Safe compartment:\n$code\n");
	}
	local $_ = $self; # The 'local' is required for garbage collection
	$output = $compartment->reval($code);
    } else {
	$code = "package ".
	    ($attr->{'package'} || "HTML::EP::main").";".$code;
	if ($self->{debug}) {
	    $self->HTML::EP::print("Evaluating script:\n$code\n");
	}
	local $_ = $self; # The 'local' is required for garbage collection
	$output = eval $code;
    }
    if ($@) { die $@ };
    if ($self->{debug}) {
	$self->printf("Script returned:\n$output\nEnd of output.\n");
    }
    if ($attr->{output}) {
	my $type = lc $attr->{output};
	if ($type eq 'html') {
	    $output = HTML::Entities::encode($output);
	} elsif ($type eq 'url') {
	    $output = URI::Escape::uri_escape($output);
	}
    }
    $output;
}
end_of__ep_perl


_ep_database => <<'end_of__ep_database',
sub _ep_database ($$;$) {
    my $self = shift; my $attr = shift;
    my $dsn = $attr->{'dsn'} || $self->{env}->{DBI_DSN};
    my $user = $attr->{'user'} || $self->{env}->{DBI_USER};
    my $pass = $attr->{'password'} || $self->{env}->{DBI_PASS};
    my $dbhvar = $attr->{'dbh'} || 'dbh';
    require DBI;
    if ($self->{debug}) {
	$self->printf("Connecting to database: dsn = %s, user = %s,"
		      . " pass = %s\n", $dsn, $user, $pass);
    }
    $self->{$dbhvar} = DBI->connect($dsn, $user, $pass,
				    { 'RaiseError' => 1, 'Warn' => 0,
				      'PrintError' => 0 });
    '';
}
end_of__ep_database


_ep_query => <<'end_of__ep_query',
sub _ep_query ($$;$) {
    my $self = shift; my $attr = shift;
    my $statement = $attr->{statement};
    my $resultmethod =
	(exists($attr->{resulttype})  &&  $attr->{'resulttype'} =~ /array/) ?
	    "fetchrow_arrayref" : "fetchrow_hashref";
    if (!defined($statement)) {
	return undef;
    }
    my $dbh = $self->{$attr->{dbh} || 'dbh'};
    if (!$dbh) { die "Not connected"; }
    if ($self->{debug}) {
	$self->print("Executing query, statement = $statement\n");
	if ($attr->{'startat'}) {
	    $self->printf("Result starting at row %s\n",
			  $attr->{'startat'} || 0);
	}
	if (exists($attr->{'limit'})) {
	    $self->printf("Rows limited to %s\n", $attr->{'limit'});
	}
    }
    if (my $result = $attr->{result}) {
	my $start_at = $attr->{'startat'} || 0;
	my $limit = $attr->{'limit'} || -1;
	my $sth;
	if (($start_at  ||  $limit != -1)  &&
	    $dbh->{'ImplementorClass'} eq 'DBD::mysql::db') {
	    $sth = $dbh->prepare("$statement LIMIT $start_at, $limit");
	} else {
	    $sth = $dbh->prepare($statement);
	}
	$sth->execute();
	my $list = [];
	my $ref;
	while ($limit  &&  $start_at-- > 0) {
	    if (!$sth->fetchrow_arrayref()) {
		$limit = 0;
		last;
	    }
	}
	while ($limit--  &&  ($ref = $sth->$resultmethod())) {
	    push(@$list, (ref($ref) eq 'ARRAY') ? [@$ref] : {%$ref});
	}
        if (exists($attr->{'resulttype'})  &&
            $attr->{'resulttype'} =~ /^single_/) {
            $self->{$result} = $list->[0];
        } else {
	    $self->{$result} = $list;
        }
	$self->{"${result}_rows"} = scalar(@$list);
	if ($self->{debug}) {
	    $self->print("Result: ", scalar(@$list), " rows.\n");
	}
    } else {
	$dbh->do($statement);
    }
    '';
}
end_of__ep_query


_ep_select => <<'end_of__ep_select',
sub _ep_select ($$;$) {
    my $self = shift; my $attr = shift;
    if (!exists($attr->{'template'})) {
	return undef;
    }
    my @tags;
    my($var, $val);
    while (($var, $val) = each %$attr) {
	if ($var !~ /^template|range|format|items?|selected(?:\-text)?$/i){
	    push(@tags, sprintf('%s="%s"', $var,
			        HTML::Entities::encode($val)));
	}
    }

    $attr->{'format'} = '<SELECT ' . join(" ", @tags) . '>$@output$</SELECT>';
    $self->_ep_list($attr);
}
end_of__ep_select


_ep_list => <<'end_of__ep_list',
sub _ep_list ($$;$) {
    my $self = shift; my $attr = shift;
    my $template;
    if (!defined($template = $attr->{template})) {
	return undef;
    }
    my $output = '';
    my($list, $range);
    if ($range = $attr->{'range'}) {
	if ($range =~ /(\d+)\.\.(\d+)/) {
	    $list = [$1 .. $2];
	} else {
	    $list = [split(/,/, $range)];
	}
    } else {
	$list = $self->{$attr->{items}};
    }
    my $l = $attr->{item} or die "Missing item name";
    my $ref;
    my $i = 0;
    my $selected = $attr->{'selected'};
    my $isSelected;
    foreach $ref (@$list) {
	$self->{$l} = $ref;
	$self->{i} = $i++;
	if ($selected) {
	    if (ref($ref)  eq  'HASH') {
		$isSelected = $ref->{'val'} eq $selected;
	    } elsif (ref($ref) eq 'ARRAY') {
		$isSelected = $ref->[0] eq $selected;
	    } else {
		$isSelected = $ref eq $selected;
	    }
	    $self->{'selected'} = $isSelected ?
		($attr->{'selected-text'} || 'SELECTED') : '';
	}
	$output .= $self->ParseVars($template);
    }
    if (my $format = $attr->{'format'}) {
	$attr->{'output'} = $output;
	$format =~ s/\$([\@\#\~]?)(\w+)((\-\>\w+)*)\$/HTML::EP::ParseVar($attr, $1, $2, $3)/eg;
	$format;
    } else {
	$output;
    }
}
end_of__ep_list


_ep_errhandler => <<'end_of__ep_errhandler',
sub _ep_errhandler ($$;$) {
    my($self, $attr) = @_;
    my $type = $attr->{type};
    $type = ($type  &&  (lc $type) eq 'user') ? 'user' : 'system';
    if ($attr->{src}) {
	$self->{'_ep_err_file_' . $type} = $attr->{src};
    } else {
	my $template = $attr->{template};
	if (!defined($template)) {
	    return undef;
	}
	$self->{'_ep_err_msg_' . $type} = ($attr->{template} || '');
    }
    '';
}
end_of__ep_errhandler


_ep_error => <<'end_of__ep_error',
sub _ep_error ($$;$) {
    my($self, $attr) = @_;
    my $msg = $attr->{msg};
    if (!defined($msg)) { return undef; }
    my $type = $attr->{type};
    $self->{_ep_err_type} = ($type  &&  (lc $type) eq 'user') ? 1 : 0;
    die $msg;
    '';
}
end_of__ep_error


_ep_input => <<'end_of__ep_input',
sub _ep_input ($$;$) {
    my($self, $attr) = @_;
    my $prefix = $attr->{prefix};
    my($var, $val);
    my $cgi = $self->{cgi};
    my @params = $cgi->param();
    my $i = 0;
    my $list = $attr->{'list'};
    my $dest = $attr->{'dest'};

    my($dbh, @names, @values);
    if ($attr->{'sqlquery'}) {
	$dbh = $self->{'dbh'} ||
	    die "Missing database-handle (Did you run ep-database`";
	if ($list) {
	    die "Cannot create 'names', 'values' and 'update' attributes"
		. " if 'list' is set.";
	}
    }

    if ($list) {
	$self->{$dest} = [];
    }
    while(1) {
	my $p = $prefix;
	my $hash = {};
	if ($list) {
	    $p .= "${i}_";
	}
	foreach $var (@params) {
	    if ($var =~ /^\Q$p\E\_?(\w+?)_(.*)$/) {
		my $col = $2;
		my $type = $1;
		if ($type =~ /^d[dmy]$/) {
		    # A date
		    if ($hash->{$col}) {
			# Do this only once
			next;
		    }
		    if (!$hash->{$col}) {
			my $year = $cgi->param("${p}dy_$col");
			my $month = $cgi->param("${p}dm_$col");
			my $day = $cgi->param("${p}dd_$col");
			if ($year < 20) {
			    $year += 2000;
			} elsif ($year < 100) {
			    $year += 1900;
			}
			$val = sprintf("%04d-%02d-%02d", $year, $month, $day);
			$hash->{$col} = { col => $col,
					  val => $val,
					  type => 'd',
					  year => $year,
					  month => $month,
					  day => $day
					  };
		    }
		} else {
		    $val = ($type eq 's') ?
			join(",", $cgi->param($var)) : $cgi->param($var);
		    $hash->{$col} = { col => $col,
				      type => $type,
				      val => $val
				      };
		}
		if ($dbh) {
		    push @names, $col;
		    push @values, ($type eq 'n') ? $val : $dbh->quote($val);
		}
	    }
	}
	if ($list) {
	    if (!%$hash) {
		last;
	    }
	    $hash->{'i'} = $i++;
	    push(@{$self->{$dest}}, $hash);
	} else {
	    if ($dbh) {
		$hash->{'names'} = join(', ', @names);
		$hash->{'values'} = join(', ', @values);
		$i = 0;
		$hash->{'update'} = join(', ',
					 map { $_." = ".$values[$i++] }
					 @names);
	    }
	    $self->{$dest} = $hash;
	    last;
	}
    }
    '';
}
end_of__ep_input


_ep_elseif => <<'end_of__ep_elseif',
sub _ep_elseif ($$;$) {
    my($self, $attr, $func) = @_;
    my $stack = $self->{_ep_stack};
    if (!@$stack) {
	die "$func without if";
    }
    my $pop = $stack->[$#$stack];
    if ($pop->{tag} ne 'ep-if') {
	die "elseif without if, got " . $pop->{tag};
    }
    if ($pop->{current}) {
	$pop->{result} = $self->{_ep_output};
	$pop->{current} = $self->{_ep_state} = 0;
    } elsif (!defined($pop->{result})) {
	$pop->{current} = !$func->{condition} || ($attr->{'eval'} ? 1 : 0);
	$self->{_ep_state} = $pop->{current} && $pop->{state};
	if ($self->{debug}) {
	    $self->print($pop->{tag}, ": Eval = '",
			 (defined($attr->{'eval'}) ? $attr->{'eval'} : ''),
			 "' changing state to ",
			 ($self->{_ep_state} ? 1 : 0), "\n");
	}
    }
    $self->{_ep_output} = '';
}
end_of__ep_elseif


_ep_mail => <<'end_of__ep_mail',
sub _ep_mail ($$;$) {
    my($self, $attr, $func) = @_;

    my $body = delete $attr->{body};
    my $host = (delete $attr->{mailserver});
    if (!$host) {
	$host = $self->{'_ep_config'}->{'mailhost'} || '127.0.0.1';
    }
    my @options;
    if (!defined($body)) {
	return undef;
    }
    require Mail::Header;
    my $msg = new Mail::Header;
    my($header, $val);
    foreach $header ('to', 'from', 'subject') {
	if (!$attr->{$header}) {
	    die "Missing header attribute: $header";
	}
    }
    foreach $header ('To', 'Cc', 'Bcc') {
	my $h = lc $header;
	if ($attr->{$h}) {
	    my $list = [split (/,/, $attr->{$h})];
	    push(@options, $header, $list);
	    if ($header ne 'Bcc') {
		foreach $val (@$list) {
		    $msg->add($h, $val);
		}
	    }
	    delete $attr->{$h};
	}
    }
    while (($header, $val) = each %$attr) {
	$msg->add($header, $val);
    }
    require Net::SMTP;
    require Mail::Internet;
    my $debug = $self->{'debug'};
    if ($debug) {
        $self->print("Making SMTP connection to $host.\n")
    }
    my $smtp = Net::SMTP->new($host, 'Debug' => $debug)
        or die "Cannot open SMTP connection to $host: $!";
    my $mail = Mail::Internet->new([$self->ParseVars($body)], Header => $msg);
    $Mail::Util::mailaddress = $attr->{'from'}; # Ugly hack to prevent
                                                # DNS lookup for 'mailhost'
                                                # in Mail::Util::mailaddress().
    $mail->smtpsend('Host' => $smtp, @options);
    '';
}
end_of__ep_mail


_ep_include => <<'end_of__ep_include',
sub _ep_include ($$;$) {
    my $self = shift; my $attr = shift;
    my $parser = $self->new($self);
    my $f = $attr->{'file'}  ||  die "Missing file name\n";
    $parser->{'env'}->{'PATH_TRANSLATED'} = (-f $f) ? $f :
	($self->{'env'}->{'DOCUMENT_ROOT'} || '') . $f;
    my $output = eval { $parser->Run(); };
    $self->{'_ep_cookies'} = $parser->{'_ep_cookies'};
    if ($@) {
	if ($@ =~ /_ep_exit, ignore/) {
	    $output = $parser->{'_ep_output'};
	} else {
	    my $type = 'system';
	    if ($self->{'_ep_err_type'} = $parser->{'_ep_err_type'}) {
		$type = 'user';
	    }
	    if (defined(my $file = $parser->{"_ep_err_file_$type"})) {
		$self->{"_ep_err_file_$type"} = $file;
	    }
	    if (defined(my $msg = $parser->{"_ep_err_msg_$type"})) {
		$self->{"_ep_err_msg_$type"} = $msg;
	    }
	    die $@;
	}
    }
    $output;
}
end_of__ep_include


_ep_exit => <<'end_of__ep_exit',
sub _ep_exit ($$;$) {
    my $self = shift;

    # At this point we have a problem, if we are inside an <ep-if>,
    # as _ep_output is currently not valid. Even worse, we might be
    # inside a nested ep-if ...
    my $stack = $self->{'_ep_stack'};
    my $pop;
    while ($pop = pop(@$stack)) {
	if ($pop->{'tag'} eq 'ep-if') {
	    $self->{'_ep_output'} = $pop->{'output'} . $self->{'_ep_output'};
	}
    }

    die "_ep_exit, ignore";
    '';
}
end_of__ep_exit


);


END_OF_AUTOLOADED_ROUTINES
