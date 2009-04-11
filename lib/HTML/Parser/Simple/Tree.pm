# Author:
#	Mark Stosberg <mark@summersault.com>
package HTML::Parser::Simple::Tree;
use base Tree::Simple;
use Carp;
use strict;
use warnings;

=head1 NAME

C<HTML::Parser::Simple::Tree> - represent HTML as a Tree::Simple tree

=head1 Synopsis

Generally this module is used through L<HTML::Parser::Simple>, not directly. 

=head1 METHODS

This class inherits all the methods from L<Tree::Simple> and adds the following
new ones which apply to HTML trees. 

=head2 get_attr_string

 my $attr_str = $self->get_attr_string. 

Return the attributes for a tag as a string.  It assumes that the attribute
string was previously set through a constructor:

 HTML::Parser::Simple::Tree->new( {
    attributes => ' height="20" width="20"',
    # ...
 }, $parent);

=cut

sub get_attr_string { 
    my $self = shift;
    return $self->getNodeValue->{attributes}; 
} 

=head2 get_attr()
 
 my $attrs_ref = $self->get_attr;
 my $val       = $self->get_attr('value'); 

If you have a start tag, this will return a hash ref with the attribute names as keys and the values as the values.

If you pass in an attribute name, it will return the value for just that attribute.

=cut 

# Should also return false if the token is not a start tag, but how?
# Or perhaps only start tags become nodes? 
sub get_attr {
    my $self = shift;
    my $key = shift;    

    # Only parse each attribute string once. 
    unless ($self->{__attrs}  ) {   
        my $attr_str  = $self->get_attr_string;
        $self->{__attrs} = $self->parse_attributes($attr_str);
    }

    if ($key) {
        # XXX Check to see if the key exists first?
        return $self->{__attrs}{$key};
    }
    else {
        return $self->{__attrs};
    }

}

=head2 parse_attributes

 $attr_href = $self->parse_attributes($attribute_string);

Parses a string of HTML attributes and returns the result as a hash ref, or
dies if the string is a valid attribute string. Attribute values may be quoted
with double quotes, single quotes, no quotes if there are no spaces in the value. 

=cut

our $quote_re  = qr{^([a-zA-Z0-9_-]+)\s*=\s*["]([^"]+)["]\s*(.*)$}so; # regular quotes
our $squote_re = qr{^([a-zA-Z0-9_-]+)\s*=\s*[']([^']+)[']\s*(.*)$}so; # single quotes
our $uquote_re = qr{^([a-zA-Z0-9_-]+)\s*=\s*([^\s'"]+)\s*(.*)$}so; # unquoted
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
    while (length $astring) {
        for my  $m ($quote_re, $squote_re, $uquote_re) {
            if ($astring =~ $m) {
                my ($var,$val,$suffix) = ($1,$2,$3);
                $attrs{$var} = $val;
                $astring = $suffix;
            }
        }
        if ($astring eq $org) {
            croak "parse_attributes: can't parse $astring - not a properly formed attribute string"
        }

    }

    return \%attrs;
}

=head1 Required Modules

=over 4

=item Carp

=item Tree::Simple

=back

=head1 Author

C<HTML::Parser::Simple::Tree> was written by Mark Stosberg I<E<lt>mark@summersault.comE<gt>> in 2009.

Home page: http://mark.stosberg.com/

=head1 Copyright

Copyright (c) 2009 Mark Stosberg.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut




