package HTML::Parser::Simple::Compat;
use base 'HTML::Parser::Simple';
use HTML::Parser::Simple::Attributes;

use strict;
use warnings;

=head1 NAME

HTML::Parser::Simple::Compat

=head1 DESCRIPTION

Be as compatible as possible with the HTML::Parser 2.x API

=cut

sub parse_start_tag {
	my($self, $tag_name, $attributes, $unary, $stack) = @_;

    my $a_parser = HTML::Parser::Simple::Attributes->new($attributes);

    # All the attributes as a hashref
    my $attr_href = $a_parser->get_attr();

    unless ($self->case_sensitive) {
        $tag_name = lc $tag_name;
        # XXX This could perhaps be more efficiently done with the Attributes module
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

    # Here's a place where we differ with the super class.
    # We depend purely on the parsing to set the value of $unary,
    # but keep the parent's logic about when push something on the stack. 
    #	$unary = $$self{'_empty'}{$lc_tag_name} || $unary;
	if (not ($$self{'_empty'}{$lc_tag_name} || $unary)) {
		push @$stack, $lc_tag_name;
	}

    # XXX Fake the order the attributes
    my $attr_seq = [ keys %$attr_href ] ;

    # XXX Fake orig text
    my $maybe_slash = $unary ? ' /' : '';
#    $attributes ||= '';
    my $orig_text = qq{<$tag_name$attributes$maybe_slash>};

    if ($unary) {
        $attr_href->{'/'} = 1,
    }

	$self ->start($tag_name, $attr_href, $attr_seq, $orig_text);
}
sub start { die "must be defined in subclass"  }

sub handle_content {
    my ($self,$origtext) = @_;
    return $self->text($origtext);  
}
sub text { die "most be defined in subclass" } 

sub parse_end_tag {
	my($self, $tag_name, $stack) = @_;

    unless ($self->case_sensitive) {
        $tag_name = lc $tag_name;
    }
    $self->SUPER::parse_end_tag($tag_name,$stack); 
}

sub handle_end_tag {
	my($self, $tag_name) = @_;

    # XXX fake the $orig_text
    my $orig_text = "</$tag_name>";
    $self->end($tag_name,$orig_text);
}
sub end { die "must define in subclass" } 

sub handle_comment {
    my ($self,$origtext) = @_;
    return $self->comment($origtext);  
}
sub comment { die "must be defined in subclass" } 

sub handle_xml_declaration {
    my ($self, $s) = @_;
    # XXX, note we only handle XML, not HTML
    $self->declaration('xml',$s);
}
sub declaration { die "must be defined in subclass" }; 

# right now we don't call this. 
sub process { die "must be defined in subclass" }; 

sub attr_encoded {
    my $self = shift; 
    # XXX right now this defined for compatibility,
    # It doesn't do anything yet. 
}

=head2 case_sensitive() 

 $bool =  $p->case_sensitive($bool);

By default, tagnames and attribute names are down-cased.  Enabling this
attribute leaves them as found in the HTML source document.

=cut

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


1;
