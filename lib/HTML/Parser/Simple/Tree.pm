# Author:
#	Mark Stosberg <mark@summersault.com>
package HTML::Parser::Simple::Tree;
use base Tree::Simple;
use Carp;
use strict;
use warnings;

=head2 astring

return the attributes for a tag as a string

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

# Should also return false if the token is not a start tag, but how/

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

# -----------------------------------------------


our $quote_re  = qr{^([a-zA-Z0-9_-]+)\s*=\s*["]([^"]+)["]\s*(.*)$}o; # regular quotes
our $squote_re = qr{^([a-zA-Z0-9_-]+)\s*=\s*[']([^']+)[']\s*(.*)$}o; # single quotes
our $uquote_re = qr{^([a-zA-Z0-9_-]+)\s*=\s*([^\s'"]+)\s*(.*)$}o; # unquoted

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





