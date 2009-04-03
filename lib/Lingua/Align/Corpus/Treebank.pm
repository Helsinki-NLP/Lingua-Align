package Lingua::Align::Corpus::Treebank;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::Corpus);
$VERSION = '0.01';

use Lingua::Align::Corpus;
use Lingua::Align::Corpus::Treebank::Penn;
use Lingua::Align::Corpus::Treebank::TigerXML;
# use Lingua::Align::Corpus::Treebank::AlpinoXML;


sub new{
    my $class=shift;
    my %attr=@_;

    if ($attr{-type}=~/tiger/i){
	return new Lingua::Align::Corpus::Treebank::TigerXML(%attr);
    }
    return new Lingua::Align::Corpus::Treebank::Penn(%attr);
}


# next sentence returns a tree for the next sentence
# (here: only virtual function ....)
sub next_sentence{}

sub get_all_leafs{
    my $self=shift;
    my ($tree,$attr)=@_;
    $attr = 'word' if (not defined $attr);
    my @words=();
    if (ref($tree->{TERMINALS}) eq 'ARRAY'){
	foreach my $n (@{$tree->{TERMINALS}}){
	    push(@words,$tree->{NODES}->{$n}->{$attr});
	}
    }
    return @words;
}

sub get_outside_leafs{
    my $self=shift;
    my ($tree,$node,$attr)=@_;
    $attr = 'word' if (not defined $attr);

    ## check if subtree leafs with the specified attr are already stored
    if (exists($tree->{NODES}->{$node}->{OUTLEAFS})){
	if (exists($tree->{NODES}->{$node}->{OUTLEAFS}->{$attr})){
	    if (ref($tree->{NODES}->{$node}->{OUTLEAFS}->{$attr}) eq 'ARRAY'){
		return @{$tree->{NODES}->{$node}->{OUTLEAFS}->{$attr}};
	    }
	}
	## if we have IDs --> get the attribute from the nodes
	elsif (exists($tree->{NODES}->{$node}->{OUTLEAFS}->{id})){
	    if (ref($tree->{NODES}->{$node}->{OUTLEAFS}->{id}) eq 'ARRAY'){
		my @ids = @{$tree->{NODES}->{$node}->{OUTLEAFS}->{id}};
		my @val=();
		foreach my $i (@ids){
		    push (@val,$tree->{NODES}->{$i}->{$attr});
		}
		return @val;
	    }
	}
    }

    my @leafs=@{$tree->{TERMINALS}};
    my @ids = $self->get_leafs($tree,$node,'id');

    my %inside=();
    foreach (@ids){$inside{$_}=1;}

    my @outside=();
    foreach (@leafs){
	if (!exists($inside{$_})){
	    push(@outside,$tree->{NODES}->{$_}->{$attr});
	}
    }
    ## cache this
    @{$tree->{NODES}->{$node}->{OUTLEAFS}->{$attr}}=@outside;
    return @outside;
}





sub get_leafs{
    my $self=shift;
    my ($tree,$node,$attr)=@_;
    return () if (ref($tree) ne 'HASH');
    return () if (ref($tree->{NODES}) ne 'HASH');

    $attr = 'word' if (not defined $attr);

    if (exists $tree->{NODES}->{$node}){

	## check if subtree leafs with the specified attr are already stored
	if (exists($tree->{NODES}->{$node}->{LEAFS})){
	    if (exists($tree->{NODES}->{$node}->{LEAFS}->{$attr})){
		if (ref($tree->{NODES}->{$node}->{LEAFS}->{$attr}) eq 'ARRAY'){
		    return @{$tree->{NODES}->{$node}->{LEAFS}->{$attr}};
		}
	    }
	    ## if we have IDs --> get the attribute from the nodes
	    elsif (exists($tree->{NODES}->{$node}->{LEAFS}->{id})){
		if (ref($tree->{NODES}->{$node}->{LEAFS}->{id}) eq 'ARRAY'){
		    my @ids = @{$tree->{NODES}->{$node}->{LEAFS}->{id}};
		    my @val=();
		    foreach my $i (@ids){
			push (@val,$tree->{NODES}->{$i}->{$attr});
		    }
		    return @val;
		}
	    }
	}

	## otherwise: go through all children
	if (exists $tree->{NODES}->{$node}->{CHILDREN}){
	    if (ref($tree->{NODES}->{$node}->{CHILDREN}) eq 'ARRAY'){
		my @leafs=();
		foreach my $c (@{$tree->{NODES}->{$node}->{CHILDREN}}){
		    push(@leafs,$self->get_leafs($tree,$c,$attr));
		}
		## cache subtree leafs ....
		@{$tree->{NODES}->{$node}->{LEAFS}->{$attr}}=@leafs;
		return @leafs;
	    }
	}
	else{
	    return ($tree->{NODES}->{$node}->{$attr});
	}
    }
}




1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

YADWA::Data::Trees - Perl extension for blah blah blah

=head1 SYNOPSIS

  use YADWA::Data::Trees;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for YADWA::Data::Trees, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Joerg Tiedemann, E<lt>tiedeman@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
