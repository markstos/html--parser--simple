use Test::More 'no_plan';
use HTML::Parser::Simple;
use strict;
use warnings;

my $p = HTML::Parser::Simple -> new;
$p -> parse('<html><body><form><input type="text" name="my_name" value="my_value"></form></body></html>');

is( (ref $p->get_current_node)
    , 'HTML::Parser::Simple::Tree'
    , 'get_current_node() returns an HTML::Parser::Simple::Tree object');
