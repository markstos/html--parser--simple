use Test::More 'no_plan';
use strict;
use warnings;

use HTML::Parser::Simple::Tree;

my $tree = HTML::Parser::Simple::Tree->new;

my $a = $tree->parse_attributes( q{ type=text name="my_name" 
        value='my value' 
        id="O'Hare" });

is($a->{type},'text', 'unquoted attribute is parsed');
is($a->{name},'my_name', 'double quoted attribute is parsed');
is($a->{value},'my value', 'single quoted attribute with space is parsed');
is($a->{id},"O'Hare", 'double quoted attribute with embedded single quote is parsed');
