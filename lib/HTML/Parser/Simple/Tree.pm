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

1;

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
