use Test::More 'no_plan';
use strict;
use warnings;

use HTML::Parser::Simple;

my $p = HTML::Parser::Simple->new;

my ($a,$seq) = $p->parse_attributes(
q{ type=text name="my_name"
        value='my value'
        id="O'Hare"
        checked
        with_space = "true"
    });

is($a->{type},'text', 'unquoted attribute is parsed');
is($a->{name},'my_name', 'double quoted attribute is parsed');
is($a->{value},'my value', 'single quoted attribute with space is parsed');
is($a->{id},"O'Hare", 'double quoted attribute with embedded single quote is parsed');
is($a->{with_space},"true", 'attribute with spaces around "=" is parsed');
is($a->{checked},"checked", '"checked" is accepted and value is set to key ');
is_deeply($seq
    , [qw[type name value id checked with_space]]
    , "attr_seq is returned in order expected");

