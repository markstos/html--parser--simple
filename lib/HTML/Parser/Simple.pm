package HTML::Parser::Simple;
use strict;
use warnings;

require 5.005_62;

use Carp;

our $VERSION = '1.02';

# Encapsulated class data.
{
	my  %_attr_data  = (
	 _xhtml      => 0,
	);

	sub _default_for {
		my($self, $attr_name) = @_;
		$_attr_data{$attr_name};
	}

	sub _standard_keys {
		keys %_attr_data;
	}
}

sub handle_comment {
	my($self, $s) = @_;
	$self -> handle_content($s);
}

sub handle_content {
    my ($self, $content) = @_;
    # Sub-class to do something interesting;
    return 1;
}

sub handle_doctype {
	my($self, $s) = @_;
	$self -> handle_content($s);
}

sub handle_end_tag {
	my($self, $tag_name) = @_;
    # Sub-class to do something interesting.
    return 1;
}

sub handle_start_tag {
	my($self, $tag_name, $attributes, $unary) = @_;
    # Sub-class to do something interesting.
    return 1;
}

sub handle_xml_declaration {
	my($self, $s) = @_;
	$self->handle_content($s);
}

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self->init(@_);
}

sub init {
    my $self = shift;
	my $arg  = shift;

    $self->{_stack}        = []; # list of start targs in the order they are found.
    $self->{_in_content} = 0 ; # a boolean. Tracks whether the current point in parsing is in content or not. 

	for my $attr_name ($self -> _standard_keys() ) {
		my($arg_name) = $attr_name =~ /^_(.*)/;

		if (exists($$arg{$arg_name}) ) {
			$$self{$attr_name} = $$arg{$arg_name};
		}
		else {
			$$self{$attr_name} = $self -> _default_for($attr_name);
		}
	}

    # Block Elements - HTML 4.01
	$$self{'_block'} = _make_map(qw{ address applet blockquote button center dd del dir div dl dt fieldset form frameset hr iframe ins isindex li map menu noframes noscript object ol p pre script table tbody td tfoot th thead tr ul});

    # Elements that you can, intentionally, leave open
    # (and which close themselves)
	$$self{'_close_self'} = _make_map(qw{ colgroup dd dt li option p td tfoot th thead tr });

    # Empty Elements - HTML 4.01
	$$self{'_empty'} = _make_map(qw{ area base basefont br col embed frame hr img input isindex link meta param wbr });

    # Inline Elements - HTML 4.01
	$$self{'_inline'} = _make_map(qw{ a abbr acronym applet b basefont bdo big br button cite code del dfn em font i iframe img input ins kbd label map object q s samp script select small span strike strong sub sup textarea tt u var });

	$$self{'_known_tag'} = {%{$$self{'_block'} }, %{$$self{'_close_self'} }, %{$$self{'_empty'} }, %{$$self{'_inline'} } };

	if ($self ->{'_xhtml'} ) {
		# Compared to the non-XHTML re, this has a extra  ':' just under the ':'.

		$$self{'_tag_with_attribute'} = q#^(<(\w+)((?:\s+[-:\w]+(?:\s*=\s*(?:(?:"[^"]*")|(?:'[^']*')|[^>\s]+))?)*)\s*(\/?)>)#;
	}
	else {
		$$self{'_tag_with_attribute'} = q#^(<(\w+)((?:\s+[-\w]+(?:\s*=\s*(?:(?:"[^"]*")|(?:'[^']*')|[^>\s]+))?)*)\s*(\/?)>)#;
	}

	return $self;

}	# End of new.

# -----------------------------------------------

sub parse {
	my($self, $html) = @_;
	my($original)    = $html;
	my(%special)     = (
	 script => 1,
	 style  => 1,
	);

    my $offset; # position relative to the beginning of the chunk
    my $s; # current snippet of HTML we are testing and parsing

    # Use $stack as a shorthand. Since they are both references, as $stack is updated, our internal stack will be too.
	my $stack = $self->{_stack};

	for (; $html;) {
		$self->{_in_content} = 1;

		# Make sure we're not in a script or style element.

		if (! $$stack[$#$stack] || ! $special{$$stack[$#$stack]}) {
			# Rearrange order of testing so rarer possiblilites are further down.
			# Is it an end tag?

			$s = substr($html, 0, 2);

			if ($s eq '</') {
				if ($html =~ /^(<\/(\w+)[^>]*>)/) {
                    my ($whole_tag,$tag_name) = ($1,$2);
					substr($html, 0, length $whole_tag) = '';
					$self->{_in_content}                 = 0;

					$self -> parse_end_tag($tag_name, $stack);
				}
			}

			# Is it a start tag?

			if ($self->{_in_content}) {
				if (substr($html, 0, 1) eq '<') {
					if ($html =~ /$$self{'_tag_with_attribute'}/) {
                        my ($orig_text,$tag_name,$attr_string,$unary) = ($1,$2,$3,$4);
						substr($html, 0, length $orig_text) = '';
						$self->{_in_content}                 = 0;

						$self -> parse_start_tag($tag_name, $attr_string, $unary, $stack);
					}
				}
			}

			# Is it a comment?

			if ($self->{_in_content}) {
				$s = substr($html, 0, 4);

				if ($s eq '<!--') {
					$offset = index($html, '-->');

					if ($offset >= 0) {
						$self -> handle_comment(substr($html, 0, ($offset + 3) ) );

						substr($html, 0, $offset + 3) = '';
						$self->{_in_content}                   = 0;
					}
				}
			}

			# Is it a doctype?

			if ($self->{_in_content}) {
				$s = substr($html, 0, 9);

				if ($s eq '<!DOCTYPE') {
					$offset = index($html, '>');

					if ($offset >= 0) {
						$self -> handle_doctype(substr($html, 0, ($offset + 1) ) );

						substr($html, 0, $offset + 1) = '';
						$self->{_in_content}                   = 0;
					}
				}
			}

			# Is is an XML declaration?

			if ($self ->{'_xhtml'} && $self->{_in_content}) {
				$s = substr($html, 0, 5);

				if ($s eq '<?xml') {
					$offset = index($html, '?>');

					if ($offset >= 0) {
						$self -> handle_xml_declaration(substr($html, 0, ($offset + 2) ) );

						substr($html, 0, $offset + 2) = '';
						$self->{_in_content}                   = 0;
					}
				}
			}

			if ($self->{_in_content}) {
				$offset = index($html, '<');

				if ($offset < 0) {
					$self -> handle_content($html);

					$html = '';
				}
				else {
					$self -> handle_content(substr($html, 0, $offset) );
					substr($html, 0, $offset) = '';
				}
			}
		}
		else {
			my($re) = "(.*)<\/$$stack[$#$stack]\[^>]*>";

			if ($html =~ /$re/s) {
				my($text) = $1;
				$text     =~ s/<!--(.*?)-->/$1/g;
				$text     =~ s/<!\[CDATA]\[(.*?)]]>/$1/g;

				$self -> handle_content($text);
			}

			$self -> parse_end_tag($$stack[$#$stack], $stack);
		}

		if ($html eq $original) {
            $self->handle_parse_error($html)
		}

		$original = $html;
	}


    # For compatibility with HTML::Parser;
    return $self;
}

our $quote_re  = qr{^([a-zA-Z0-9_-]+)\s*=\s*["]([^"]+)["]\s*(.*)$}so; # regular quotes
our $squote_re = qr{^([a-zA-Z0-9_-]+)\s*=\s*[']([^']+)[']\s*(.*)$}so; # single quotes
our $uquote_re = qr{^([a-zA-Z0-9_-]+)\s*=\s*([^\s'"]+)\s*(.*)$}so;    # unquoted
our $bool_re   = qr{^([a-zA-Z0-9_-]+)\s*(.*)$}so;                     # a boolean, like "checked"

sub parse_attributes {
    my $self = shift;
    my $astring = shift;

    # No attribute string? We're done. 
    unless (defined $astring and length $astring) {
        return {};
    }

    my %attrs;

    # trim leading and trailing whitespace.
    # XXX faster as two REs?
    $astring =~ s/^\s+|\s+$//g;

    my $org = $astring;
    BIT: while (length $astring) {
        for my  $m ($quote_re, $squote_re, $uquote_re) {
            if ($astring =~ $m) {
                my ($var,$val,$suffix) = ($1,$2,$3);
                $attrs{$var} = $val;
                $astring = $suffix;
                next BIT;
            }
        }

        # For booleans, set the value to the key.
        # XXX, make this configurable, like with HTML::Parser's boolean_attribute_value method. 
        if ($astring =~ $bool_re) {
            my ($var,$suffix) = ($1,$2);
            $attrs{$var} = $var;
            $astring = $suffix;
            next BIT;
        }

#        if ($astring eq $org) {
            croak "parse_attributes: can't parse $astring - not a properly formed attribute string"
#        }

    }

    return \%attrs;
}


sub eof {
    my $self = shift; 
    
	# Clean up any remaining tags.
	$self -> parse_end_tag('', $self->{_stack} );

    return $self;
}



sub parse_end_tag {
	my($self, $tag_name, $stack) = @_;

	# Find the closest opened tag of the same name.
    my $lc_tag_name = lc $tag_name;

    # What's the furthest point up the stack we should travel?
	my $pos;

    # If we closing a specific tag, see how far up the stack it is
	if ($tag_name) {
        STACKCHECK: for ($pos = $#$stack; $pos >= 0; $pos--) {
			if ($$stack[$pos] eq $lc_tag_name) {
				last STACKCHECK;
			}
		}
	}
    # Otherwise, we are closing everthing.
	else {
		$pos = 0;
	}

	if ($pos >= 0) {
		# Close all the open tags, up the stack.
		my $count = 0;

		for (my $i = $#$stack; $i >= $pos; $i--) {
			$count++;
			$self -> handle_end_tag($$stack[$i]);
		}

		# Remove the open elements from the stack.
        splice @$stack, -$count;
	}
}

sub parse_start_tag {
	my($self, $tag_name, $attributes, $unary, $stack) = @_;

    my $lc_tag_name = lc $tag_name;

	if ($$self{'_block'}{$lc_tag_name}) {
		for (; $#$stack >= 0 && $$self{'_inline'}{$$stack[$#$stack]};) {
			$self -> parse_end_tag($$stack[$#$stack], $stack);
		}
	}

	if ($$self{'_close_self'}{$lc_tag_name} && ($$stack[$#$stack] eq $lc_tag_name) ) {
		$self -> parse_end_tag($tag_name, $stack);
	}

	$unary = $$self{'_empty'}{$lc_tag_name} || $unary;

	if (! $unary) {
		push @$stack, $lc_tag_name;
	}

	$self -> handle_start_tag($tag_name, $attributes, $unary);
}

sub handle_parse_error {
    my ($self,$remaining_html) = @_;
    Carp::croak 'Parse error. Next 100 chars: '.substr($remaining_html, 0, 100);
}

# Given an array, return a hashref where the array elements are keys, and the values are "1"
sub _make_map {
    my @list = @_;
    my %hash = map { $_ => 1 } @list;
    return \%hash
}

1;

=head1 NAME

C<HTML::Parser::Simple> - Parse nice HTML files without needing a compiler

=head1 Synopsis

	use HTML::Parser::Simple;
	my $p = HTML::Parser::Simple->new;

   # Parse document text chunk by chunk
   $p->parse($chunk1);
   $p->parse($chunk2);
   #...
   $p->eof;                 # signal end of document


=head1 Description

C<HTML::Parser::Simple> is a pure Perl HTML and XHTML Parser.

The way to use it is define handlers for the various types of
content that it discovers during parsing. For now, this is done
by defining handlers in a sub-class. A future version will allow
defining the handlers inline with callbacks.

Here are the names and signatures of the handlers you can define in your
subclass:

 sub handle_start_tag {
 	my($self, $tag_name, $attribute_string, $unary) = @_;
     # Sub-class to do something interesting.
     # to parse the attribute string, see parse_attributes()
     return 1;
 }

 sub handle_end_tag {
 	my($self, $tag_name) = @_;
     # Sub-class to do something interesting.
     return 1;
 }

 # The stuff between the tags
 sub handle_content {
     my ($self, $content) = @_;
     # Sub-class to do something interesting;
     return 1;
 }

 sub handle_comment {
 	my($self, $comment) = @_;
 	$self -> handle_content($comment);
 }

 sub handle_doctype {
 	my($self, $doctype) = @_;
 	$self -> handle_content($doctype);
 }

 sub handle_xml_declaration {
 	my($self, $s) = @_;
 	$self->handle_content($s);
 }


For examples, you can see the two sub-classes which are included in this distribution:

L<HTML::Parser::Simple::Tree> - stores the parsed document in an
L<Tree::Simple> object.  This allows for new ways to access the data, at the
expense of storing the entire HTML document in memory as a collection of
Tree::Simple objects.

L<HTML::Parser::Simple::Compat> - is designed for some compatibility with
HTML::Parser, allowing you to eliminate the compiler requirement that
HTML::Parser brings it's use of XS and C. The trade-off is that the pure Perl
approach is of course slower, and compatibility might not be perfect.


=head1 Methods

=head2 new()

 $parser = HTML::Parser::Simple->new;

new(...) returns an object of type C<HTML::Parser::Simple>.
It takes a hashref of the following options.

=over 4

=item xhtml(0|1)

This takes either a 0 or a 1.

Boolean to optionally enable the following XHTML feature

=over 4

=item Accept the XML declaration

E.g.: <?xml version="1.0" standalone='yes'?>.

=item Accept attribute names containing the ':' char

E.g.: <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">.

=back

=back

=head2 parse($html)

 $p = $p->parse($string)

Parse C<$string> as the next chunk of the HTML document.  As it encounters
different types of content, bits of content are passed to different handlers,
which you can define, to process the HTML as you wish. Returns the parser
object. See the Description above for details.  Handlers should not attempt to
modify the $string in-place until $p->parse returns.

If an invoked event handler aborts parsing by calling $p->eof, then $p->parse()
will return a FALSE value.

=head2 parse_attributes

 $attr_href = $p->parse_attributes($attr_string);
 $attr_href = HTML::Parser::Simple->parse_attributes($attr_string);

Parses a string of HTML attributes and returns the result as a hash ref, or
dies if the string is a valid attribute string. Attribute values may be quoted
with double quotes, single quotes, no quotes if there are no spaces in the value.

May also be called as a class method.

=head2 eof

Signals the end of the HTML document. All remaining HTML tags on the internal 
parse stack will now be closed. 

The return value from eof() is a reference to the parser object.

The behavior of C<< eof () >> in HTML::Parser is more involved. This method
is not yet fully compatible.

=back

=head1 See Also

=head1 Credits

This Perl HTML parser has been converted from a JavaScript one written by John Resig.

http://ejohn.org/files/htmlparser.js

Well done John!  Note also the comments published here:

http://groups.google.com/group/envjs/browse_thread/thread/edd9033b9273fa58

=head1 Authors

    Ron Savage C<< ron@savage.net.au >>
    Mark Stosberg C<< mark@summersault.com >>

=head1 Copyright

Parts covered over Australian copyright (c) 2009 Ron Savage.
Other parts are copyright (c) Mark Stosberg

You can redistribute and/or modify this Perl distribution under the terms of
The Artistic License, a copy of which is available at:
http://www.opensource.org/licenses/index.html

=cut
