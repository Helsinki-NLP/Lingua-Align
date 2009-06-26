package Lingua::Align::Corpus::Treebank::Stanford;

use 5.005;
use strict;

use Lingua::Align::Corpus::Treebank::Penn;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::Corpus::Treebank::Penn);
$VERSION = '0.01';





sub read_next_sentence{
    my $self=shift;
    my ($tree)=@_;

    if ($self->SUPER::read_next_sentence(@_)){

	$self->{DEPENDENCIES}={};
	if ($self->read_dependency_relations($self->{DEPENDENCIES})){
	    $self->add_dependency_relations($self->{DEPENDENCIES},$tree);
	}
	return 1;

    }

    return 0;

}

# read the typed dependency relations from the Stanford parser output
# default: same file as the phrase-structure trees (just following the tree)
# (first argument = head, second = dependent (correct?!)

sub read_dependency_relations{
    my $self = shift;
    my $deprel = shift;

#     my $file=shift || $self->{-deprelfile};
    my $file=shift || $self->{-file};
    if (! defined $self->{FH}->{$file}){
	$self->{FH}->{$file} = $self->open_file($file);
	$self->{-file}=$file;
    }
    my $fh=$self->{FH}->{$file};

    my $found=0;
    while(<$fh>){

	# assume that first line will contain dep rel
	return $found if (/^\s*$/);

	# if we allow empty lines before dep-rel's: uncomment this instead:
	# if (/^\s*$/){
	#     return $found if $found;
	# }

	if (/^([^\(]+)\(([^\)]+)\-([0-9]+)\s*,\s*([^\)]+)\-([0-9]+)\)\s*$/){
	    my ($rel,$head,$headID,$dep,$depID)=($1,$2,$3,$4,$5);
	    $$deprel{$depID}{$headID}=$rel;
	    $found++;
	}
    }
    return $found;
}



# add lexical dependencies to the phrase-structure tree

sub add_dependency_relations{
    my $self=shift;
    my ($deprel,$tree)=@_;

    foreach my $d (keys %{$deprel}){
	foreach my $h (keys %{$$deprel{$d}}){
	    my $depNode = $tree->{TERMINALS}->[$d-1];
	    my $headNode = $tree->{TERMINALS}->[$h-1];
	    my $rel = $$deprel{$d}{$h};

	    # walk up the tree to find the node where the parent dominates
	    # both, head & dependent ...

	    my %done=();

	    # for dependent:
	    my $node = $depNode;
	    while (exists $tree->{NODES}->{$node}->{PARENTS}){

		if ($done{$node}){
		    print STDERR "I've been here before ($node) - loop?\n";
		    last;
		}

		if (exists $tree->{NODES}->{$node}->{rel}){
		    print STDERR "relation attribute exists already ";
		    print STDERR "for node $node (rel = ";
		    print STDERR $tree->{NODES}->{$node}->{rel}.")\n";
		}
		if (! scalar @{$tree->{NODES}->{$node}->{PARENTS}->[0]}){
		    print STDERR "node $node doesn't have a parent?\n";
		    print STDERR "(shouldn't be dependent ($rel)!)\n";
		    last;
		}

		my $p = $tree->{NODES}->{$node}->{PARENTS}->[0]; # only first?

		if (not exists $tree->{NODES}->{$p}){
		    print STDERR "parent node $p of node $node) not found?\n";
		    last;
		}

		my @leafs = $self->get_leafs($tree,$p,'id');     # all leafs
		if (grep ($_ eq $headNode,@leafs)){              # incl head?
		    $self->add_relation($tree,$node,$p,$rel);
#		    $tree->{NODES}->{$node}->{rel} = $rel;       # add relation
		    last;                                        # and stop
		}                                                # otherwise:
		$self->add_relation($tree,$node,$p,'hd');
#		$tree->{NODES}->{$node}->{rel} = 'hd';           # = head (?!)
		$done{$node}=1;
		$node = $p;
	    }


	    %done=();

	    # similar for head, but add 'hd' for all nodes
	    my $node = $headNode;
	    while (exists $tree->{NODES}->{$node}->{PARENTS}){

		if ($done{$node}){
		    print STDERR "I've been here before ($node) - loop?\n";
		    last;
		}

		my @leafs = $self->get_leafs($tree,$node,'id');
		last if (grep ($_ eq $depNode,@leafs));

		if (! scalar @{$tree->{NODES}->{$node}->{PARENTS}->[0]}){
		    print STDERR "node $node doesn't have a parent?\n";
		    print STDERR "(cannot move up anymore ($rel)!)\n";
		    last;
		}

		my $p = $tree->{NODES}->{$node}->{PARENTS}->[0];
		$self->add_relation($tree,$node,$p,'hd');
#		$tree->{NODES}->{$node}->{rel} = 'hd';
		$done{$node}=1;
		$node=$p;
	    }
	}
    }
}



# set the relation between parent and child nodes
# this is not very efficient ... but, well ...

sub add_relation{
    my $self=shift;
    my ($tree,$child,$parent,$rel)=@_;

    if (exists $tree->{NODES}->{$parent}->{CHILDREN}){
	for my $i (0..$#{$tree->{NODES}->{$parent}->{CHILDREN}}){
	    if ($tree->{NODES}->{$parent}->{CHILDREN}->[$i] eq $child){

#		print STDERR "replace relation $i of $parent ";
#		print STDERR "($tree->{NODES}->{$parent}->{RELATION}->[$i]) ";
#		print STDERR "with $rel\n";

		$tree->{NODES}->{$parent}->{RELATION}->[$i] = $rel;
	    }
	}
    }
}




1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

YADWA::Data::Trees::Penn - Perl extension for blah blah blah

=head1 SYNOPSIS

  use YADWA::Data::Trees::Penn;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for YADWA::Data::Trees::Penn, created by h2xs. It looks like the
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
