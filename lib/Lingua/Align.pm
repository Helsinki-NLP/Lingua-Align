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

YADWA - Perl modules for Yet Another Discriminative Word Aligner

=head1 SYNOPSIS

  use YADWA;

=head1 DESCRIPTION

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemanh@rug.nl@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
