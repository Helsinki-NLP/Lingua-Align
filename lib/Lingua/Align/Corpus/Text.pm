package Lingua::Align::Data::Text;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw();
$VERSION = '0.01';

use FileHandle;

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }
    $self->{-encoding} = $attr{-encoding} || 'utf8';

    return $self;
}


sub next_sentence{
    my $self=shift;

    my $file=shift || $self->{-file};
    my $encoding=shift || $self->{-encoding};

    if (! defined $self->{FH}->{$file}){
	$self->{FH}->{$file} = new FileHandle;
	$self->{FH}->{$file}->open("<$file") || die "cannot open file $file\n";
	binmode($self->{FH}->{$file},":encoding($encoding)");
	$self->{SENT_COUNT}->{$file}=0;
    }
    my $fh=$self->{FH}->{$file};
    if (my $sent=<$fh>){
	chomp $sent;
	$self->{SENT_COUNT}->{$file}++;
	if ($sent=~/^\<s (snum|id)=\"?([^\"]+)\"?(\s|\>)/i){
	    $self->{SENT_ID}->{$file}=$2;
	}
	else{
	    $self->{SENT_ID}->{$file}=$self->{SENT_COUNT}->{$file};
	}
	$self->{LAST_SENT_ID}=$self->{SENT_ID}->{$file};
	$sent=~s/^\<s.*?\>\s*//;
	$sent=~s/\s*\<\/s.*?\>$//;
	return split(/\s+/,$sent);
    }
    $fh->close;
    delete $self->{FH}->{$file};
    return ();
}

sub current_id{
    my $self=shift;
    if ($_[0]){
	return $self->{SENT_ID}->{$_[0]};
    }
    return $self->{LAST_SENT_ID};
}


sub close_file{
    my $self=shift;
    my $file=shift;
    if (defined $self->{FH}){
	if (defined $self->{FH}->{$file}){
	    if (ref($self->{FH}->{$file})=~/FileHandle/){
		$self->{FH}->{$file}->close;
	    }
	}
    }
}	    



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Lingua::Align::Data::Text - Perl extension for plain text corpora

=head1 SYNOPSIS

  use Lingua::Align::Data::Text;

=head1 DESCRIPTION

=head1 SEE ALSO

=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemann@rug.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
