package HTML::Parser::Simple;
use strict;
use warnings;

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

# This has no parallel in HTML::Parser. Perhaps we this should be the handled the same as "declaration()"?
sub handle_doctype {
    my($self, $s) = @_;
    $self->text($s);
}

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self->init(@_);
}

sub init {
    my $self = shift;
    my $arg  = shift;

    $self->{_stack}      = []; # list of start targs in the order they are found.
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

    # XHTML allows "xml:lang" in the <html> tag, but HTML does not allow colons in attribute names.
    my $maybe_colon  = $self ->{'_xhtml'} ? ':' : '';
    my $attr_name_re = qr/[${maybe_colon}a-zA-Z0-9_-]+/o;

    # We currently do one pass to parse that we have a tag with attributes,
    # and then a second pass to parse the attributes themselves.
    # This could be optimized to capture everything we need in one pass. 
    $$self{'_tag_with_attribute'} = qr#^(<(\w+)((?:\s+${attr_name_re}(?:\s*=\s*(?:(?:"[^"]*")|(?:'[^']*')|[^>\s]+))?)*)\s*(\/?)>)#o;

    $$self{'_quote_re'}  = qr{^($attr_name_re)\s*=\s*["]([^"]+)["]\s*(.*)$}so; # regular quotes
    $$self{'_squote_re'} = qr{^($attr_name_re)\s*=\s*[']([^']+)[']\s*(.*)$}so; # single quotes
    $$self{'_uquote_re'} = qr{^($attr_name_re)\s*=\s*([^\s'"]+)\s*(.*)$}so;    # unquoted
    $$self{'_bool_re'}   = qr{^($attr_name_re)\s*(.*)$}so;                     # a boolean, like "checked"

    return $self;

}

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
                if ($html =~ /^(<\/(\w+)[^>]*>)/o) {
                    my ($whole_tag,$tag_name) = ($1,$2);
                    substr($html, 0, length $whole_tag) = '';
                    $self->{_in_content}                 = 0;

                    $self -> parse_end_tag($tag_name, $stack);
                }
            }

            # Is it a start tag?

            if ($self->{_in_content}) {
                if (substr($html, 0, 1) eq '<') {
                    if ($html =~ $$self{'_tag_with_attribute'}) {
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
                        $self->comment(substr($html, 0, ($offset + 3) ) );

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
                        $self->handle_doctype(substr($html, 0, ($offset + 1) ) );

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
                        my $xml = substr($html, 0, ($offset + 2) );
                        $self->declaration('xml',$xml);
                        substr($html, 0, $offset + 2) = '';
                        $self->{_in_content}                   = 0;
                    }
                }
            }

            if ($self->{_in_content}) {
                $offset = index($html, '<');

                if ($offset < 0) {
                    $self->text($html);

                    $html = '';
                }
                else {
                    $self->text(substr($html, 0, $offset) );
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

                $self->text($text);
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

# Taken directly from HTML::Parser
sub parse_file {
    my($self, $file) = @_;
    my $opened;
    if (!ref($file) && ref(\$file) ne "GLOB") {
        # Assume $file is a filename
        local(*F);
        open(F, $file) || return undef;
        binmode(F);  # should we? good for byte counts
        $opened++;
        $file = *F;
    }
    my $chunk = '';
    while (read($file, $chunk, 512)) {
    $self->parse($chunk) || last;
    }
    close($file) if $opened;
    $self->eof;
}




sub parse_attributes {
    my $self = shift;
    my $astring = shift;

    # No attribute string? We're done.
    unless (defined $astring and length $astring) {
        return {};
    }

    my %attrs;
    my @attr_seq;

    # trim leading and trailing whitespace.
    # XXX faster as two REs?
    $astring =~ s/^\s+|\s+$//g;

    my $org = $astring;
    BIT: while (length $astring) {
        for my  $m ($$self{'_quote_re'}, $$self{'_squote_re'}, $$self{'_uquote_re'}) {
            if ($astring =~ $m) {
                my ($var,$val,$suffix) = ($1,$2,$3);
                $attrs{$var} = $val;
                $astring = $suffix;
                push @attr_seq, $var;
                next BIT;
            }
        }

        # For booleans, set the value to the key.
        # XXX, make this configurable, like with HTML::Parser's boolean_attribute_value method. 
        if ($astring =~ $$self{'_bool_re'}) {
            my ($var,$suffix) = ($1,$2);
            $attrs{$var} = $var;
            $astring = $suffix;
            push @attr_seq, $var;
            next BIT;
        }

#        if ($astring eq $org) {
            croak "parse_attributes: can't parse $astring - not a properly formed attribute string"
#        }

    }

    return wantarray ? (\%attrs,\@attr_seq) : \%attrs;
}


sub eof {
    my $self = shift; 

    # Clean up any remaining tags.
    $self->parse_end_tag('', $self->{_stack} );

    return $self;
}



sub parse_end_tag {
    my($self, $tag_name, $stack) = @_;

    unless ($self->case_sensitive) {
        $tag_name = lc $tag_name;
    }

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

            my $tag_name = $$stack[$i];
            # XXX fake the $orig_text
            my $orig_text = "</$tag_name>";
            $self->end($tag_name,$orig_text);
        }

        # Remove the open elements from the stack.
        splice @$stack, -$count;
    }
}

sub handle_parse_error {
    my ($self,$remaining_html) = @_;
    Carp::croak 'Parse error. Next 100 chars: '.substr($remaining_html, 0, 100);
}

sub parse_start_tag {
    my($self, $tag_name, $attributes_str, $unary, $stack) = @_;

    my ($attr_href,$attr_seq) = $self->parse_attributes($attributes_str);

    unless ($self->case_sensitive) {
        $tag_name = lc $tag_name;
        my @old_keys = keys %$attr_href;
        for my $k (@old_keys) {
            $attr_href->{ lc $k } = delete $attr_href->{$k};
        }
    }

    # This should happen even if case_sensitive isn't set, because it's about
    # internal hash lookups, not external display.
    my $lc_tag_name = lc $tag_name;

    if ($$self{'_block'}{$lc_tag_name}) {
        for (; $#$stack >= 0 && $$self{'_inline'}{$$stack[$#$stack]};) {
            $self -> parse_end_tag($$stack[$#$stack], $stack);
        }
    }

    if ($$self{'_close_self'}{$lc_tag_name} && ($$stack[$#$stack] eq $lc_tag_name) ) {
        $self -> parse_end_tag($tag_name, $stack);
    }

    #   $unary = $$self{'_empty'}{$lc_tag_name} || $unary;
    if (not ($$self{'_empty'}{$lc_tag_name} || $unary)) {
        push @$stack, $lc_tag_name;
    }

    # XXX Fake orig text
    my $maybe_slash = $unary ? ' /' : '';
#    $attributes ||= '';
    my $orig_text = qq{<$tag_name$attributes_str$maybe_slash>};

    if ($unary) {
        $attr_href->{'/'} = 1,
    }

    $self->start($tag_name, $attr_href, $attr_seq, $orig_text);
}
sub start       { die "start() must be defined in subclass"  }
sub text        { die "text() must be defined in subclass" }
sub end         { die "end() must be defined in subclass" }
sub comment     { die "comment() must be defined in subclass" }
sub declaration { die "declaration() must be defined in subclass" }
# right now we don't call this.
# sub process   { die "process() must be defined in subclass" }

sub attr_encoded {
    my $self = shift;
    # XXX right now this defined for compatibility,
    # It doesn't do anything yet.
}

sub case_sensitive {
    my $self = shift;
    my $bool = shift;
    if (defined $bool) {
        $self->{_case_sensitive} = $bool;
    }

    unless (defined $self->{_case_sensitive}) {
        $self->{_case_sensitive} = 0;
    }

    return $self->{_case_sensitive}; 
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

   # Parse directly from file
   $p->parse_file("foo.html");
   # or
   open(my $fh, "<:utf8", "foo.html") || die;
   $p->parse_file($fh);


=head1 Description

C<HTML::Parser::Simple> is a Pure-Perl HTML and XHTML Parser. It strives to be
API-compatible with the HTML::Parser 2.x API.

Currently it is sufficiently compatible to be able to be used as an alternative
super-class for L<HTML::FillInForm>. No other claims about compatibility are
currently made beyond that, but patches are welcome that make it more compatible
with the HTML::Parser APIs.

The way to use it is define handlers for the various types of content that it
discovers during parsing. For now, this is done by defining handlers in a
sub-class. A future version may allow defining the handlers inline with
callbacks.

Here are the names and signatures of the handlers you can define in your
subclass:

 # Called when an end tag is encountered
 sub end {
    my($self, $tag_name, $orig_text) = @_;
    return 1;
 }

 # Called when a start tag is encountered
 sub start {
    my ($self, $tag_name, $attr_href, $attr_seq, $orig_text);
    return 1;
 }

 # Called when stuff between tags is encountered
 sub text {
     my ($self, $content) = @_;
     return 1;
 }

 # Called when an XML declaration is found
 sub declaration {
    my ($self,$declaration_type, $declaration);
    # $declaration_type is usually 'xml'
    return 1;
 }

 # Called when an HTML comment is found.
 sub comment {
    my($self, $comment) = @_;
    return 1;
 }

For an example, you can see a subclass which is included in this distribution:

L<HTML::Parser::Simple::Tree> - stores the parsed document in an
L<Tree::Simple> object.  This allows for new ways to access the data, at the
expense of storing the entire HTML document in memory as a collection of
Tree::Simple objects.

=head1 Methods

=head2 new()

 $p = HTML::Parser::Simple->new;

new(...) returns an object of type C<HTML::Parser::Simple>.
It takes a hashref of the following options.

=over 4

=item $p->xhtml(0|1)

Boolean to optionally enable the following XHTML feature:

=over 4

=item Accept the XML declaration

E.g.: <?xml version="1.0" standalone='yes'?>.

=item Accept attribute names containing the ':' char

E.g.: <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">.

=back

=head2 $p->parse($html)

 $p = $p->parse($string)

Parse C<$string> as the next chunk of the HTML document.  As it encounters
different types of content, bits of content are passed to different handlers,
which you can define, to process the HTML as you wish. Returns the parser
object. See the Description above for details.  Handlers should not attempt to
modify the $string in-place until $p->parse returns.

If an invoked event handler aborts parsing by calling $p->eof, then $p->parse()
will return a FALSE value.

=head2 $p->parse_file( $file )

Parse text directly from a file.  The C<< $file >>  argument can be a
filename, an open file handle, or a reference to an open file
handle.

If $file contains a filename and the file can't be opened, then the
method returns an undefined value and $! tells why it failed.
Otherwise the return value is a reference to the parser object.

If a file handle is passed as the $file argument, then the file will
normally be read until EOF, but not closed.

If an invoked event handler aborts parsing by calling $p->eof,
then $p->parse_file() may not have read the entire file.

On systems with multi-byte line terminators, the values passed for the
offset and length argspecs may be too low if parse_file() is called on
a file handle that is not in binary mode.

If a filename is passed in, then parse_file() will open the file in
binary mode.

=head2 $p->parse_attributes($attr_string)

 ($attr_href,$attr_seq) = $p->parse_attributes($attr_string);
  $attr_href            = $p->parse_attributes($attr_string);

Parses a string of HTML attributes and returns the result as a hash ref, or
dies if the string is a valid attribute string. Attribute values may be quoted
with double quotes, single quotes, no quotes if there are no spaces in the value.

In list context, second return value is an arrayref which contains the keys in
the order in which they were found.

=head2 $p->eof

Signals the end of the HTML document. All remaining HTML tags on the internal 
parse stack will now be closed. 

The return value from eof() is a reference to the parser object.

The behavior of C<< eof () >> in HTML::Parser is more involved. This method
is not yet fully compatible.

=head2 $->case_sensitive()

 $bool =  $p->case_sensitive($bool);

By default, tagnames and attribute names are down-cased.  Enabling this
attribute leaves them as found in the HTML source document.

=cut

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
Other parts are copyright (c) 2009 Mark Stosberg

You can redistribute and/or modify this Perl distribution under the terms of
The Artistic License, a copy of which is available at:
http://www.opensource.org/licenses/index.html

=cut
