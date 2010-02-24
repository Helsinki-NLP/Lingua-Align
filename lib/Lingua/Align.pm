package Lingua::Align;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw();
$VERSION = '0.01';

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    return $self;
}

sub set_attr{
    my $self=shift;

    my %attr=@_;
    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }
}

sub align{}


sub store_features_used{
    my $self=shift;
    my ($model,$features)=@_;
    my $file=$model.'.feat';
    if (open F,">$file"){
	print F $features,"\n";
	close F;
    }
}

sub get_features_used{
    my $self=shift;
    my ($model)=@_;
    my $file=$model.'.feat';
    if (open F,"<$file"){
	my $features = <F>;
	chomp $features;
	close F;
	return $features;
    }
    return undef;
}



1;
__END__

=head1 NAME

Lingua::Align - Perl modules for the alignment of parallel corpora

=head1 SYNOPSIS

  use Lingua::Align;

=head1 DESCRIPTION

This module doesn't do anything. Look at Lingua::Align::Trees for the Tree Aligner. Other modules will follow later.

=head1 SEE ALSO

L<Lingua::Align::Trees>,
L<Lingua::Align::Trees::FeatureExtractor>


=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemanh@rug.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
