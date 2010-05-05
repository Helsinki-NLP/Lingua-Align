#!/usr/bin/env perl
#-*-perl-*-
#
#

use lib '/storage3/data/PACO-MT/tools/Lingua-Align-dev/lib';
use Lingua::Align::Corpus::Parallel::OPUS;



my $AlignFile = shift(@ARGV);
my $SrcTrees = shift(@ARGV);
my $SrcFormat = shift(@ARGV);

my $TrgTrees = shift(@ARGV);
my $TrgFormat = shift(@ARGV);

my $SrcOut = shift(@ARGV);
my $TrgOut = shift(@ARGV);

my $corpus = new Lingua::Align::Corpus::Parallel::OPUS(
	      -alignfile => $AlignFile,
	      -type => 'opus',
	      -src_file => $SrcTrees,
	      -src_type => $SrcFormat,
	      -trg_file => $TrgTrees,
	      -trg_type => $TrgFormat);

open S,">$SrcOut" || die "cannot write to $SrcOut!\n";
open T,">$TrgOut" || die "cannot write to $TrgOut!\n";

my %src=();
my %trg=();
my $links;

while ($corpus->next_alignment(\%src,\%trg,\$links)){
    my @srcwords=$corpus->{SRC}->get_all_leafs(\%src);
    my @trgwords=$corpus->{TRG}->get_all_leafs(\%trg);
    if (@srcwords && @trgwords){
	print S join(' ',@srcwords);
	print S "\n";
	print T join(' ',@trgwords);
	print T "\n";
    }
}

close S;
close T;


__END__

=head1 NAME

treebank2moses.pl - a script that converts an aligned parallel treebank to plain text format (Moses/Giza++ format). Sentence alignments have to be stored in OPUS (xces) format.

=head1 SYNOPSIS

    treebank2moses.pl alignfile STrees SFormat TTrees TFormat SOut TOut

=head1 DESCRIPTION


=head1 SEE ALSO

L<Lingua::Align::Corpus>
 

=head1 AUTHOR

Joerg Tiedemann, E<lt>jorg.tiedemann@lingfil.uu.seE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
