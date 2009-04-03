package Lingua::Align::Corpus::Parallel::STA;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::Corpus::Parallel);
$VERSION = '0.01';

use FileHandle;
use File::Basename;

use XML::Parser;
use Lingua::Align::Corpus::Parallel;


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


sub next_alignment{
    my $self=shift;
    my ($srctree,$trgtree,$links)=@_;

    my $file=$_[3] || $self->{-alignfile};

    # first: read all tree alignments (problem for large parallel treebanks?!)
    if ((! ref($self->{SRC})) || (! ref($self->{TRG}))){
	$self->read_tree_alignments($file);
    }

    return 0 if (not $self->{SRC}->next_sentence($srctree));
    return 0 if (not $self->{TRG}->next_sentence($trgtree));


    # if the current trees are not linked: read more trees
    # 1) no links defined for current source sentence! --> read more src
    while (not exists $self->{__XMLHANDLE__}->{SALIGN}->{$$srctree{ID}}){
	print STDERR "skip source $$srctree{ID}\n";
	return 0 if (not $self->{SRC}->next_sentence($srctree));
    }
    # 2) target sentence is not linked to current source sentence
    if ($$trgtree{ID} ne $self->{__XMLHANDLE__}->{SALIGN}->{$$srctree{ID}}){
	my $thisID=$$trgtree{ID};
	my $linkedID=$self->{__XMLHANDLE__}->{SALIGN}->{$$srctree{ID}};
	$thisID=~s/^[^0-9]*//;
	$linkedID=~s/^[^0-9]*//;
	# assume that sentence IDs are ordered upwards
	while ($thisID<$linkedID){
	    return 0 if (not $self->{TRG}->next_sentence($trgtree));
	    $thisID=$$trgtree{ID};
	    $thisID=~s/^[^0-9]*//;
	}
    }
    # still not the one?
    # 3) source sentence is not linked to current target sentence
    if ($$trgtree{ID} ne $self->{__XMLHANDLE__}->{SALIGN}->{$$srctree{ID}}){
	my $thisID=$$srctree{ID};
	my $linkedID=$self->{__XMLHANDLE__}->{TALIGN}->{$$trgtree{ID}};
	$thisID=~s/^[^0-9]*//;
	$linkedID=~s/^[^0-9]*//;
	# assume that sentence IDs are ordered upwards
	while ($thisID<$linkedID){
	    return 0 if (not $self->{SRC}->next_sentence($srctree));
	    $thisID=$$srctree{ID};
	    $thisID=~s/^[^0-9]*//;
	}
    }
    # ... that's all I can do ....

    $$links = $self->{__XMLHANDLE__}->{LINKS};
    return 1;

}


sub get_links{
    my $self=shift;
    my ($src,$trg)=@_;

    my $alllinks = $_[2] || $self->{__XMLHANDLE__}->{LINKS};

    my %links=();

    foreach my $sn (keys %{$$src{NODES}}){
	if (exists $$alllinks{$sn}){
	    foreach my $tn (keys %{$$trg{NODES}}){
		if (exists $$alllinks{$sn}{$tn}){
		    if ($$alllinks{$sn}{$tn} ne 'comment'){
			$links{$sn}{$tn} = $$alllinks{$sn}{$tn};
		    }

#		    my @inside = $trees->get_leafs(\%src,$sn,'word');
#		    my @outside = $trees->get_outside_leafs(\%src,$sn,'word');
#		    print "  src",$sn,":",join(' ',@inside),"\n";
##		    print "  src",$sn,":",join(' ',@outside),"\n";
#
#		    my @inside = $trees->get_leafs(\%trg,$tn,'word');
#		    my @outside = $trees->get_outside_leafs(\%trg,$tn,'word');
#		    print "  trg",$tn,":",join(' ',@inside),"\n";
##		    print "  trg",$tn,":",join(' ',@outside),"\n";

		}
	    }
	}
    }
    return %links;
}



sub read_tree_alignments{
    my $self=shift;
    my $file=shift;
    if (! defined $self->{FH}->{$file}){
	$self->{FH}->{$file} = new FileHandle;
	$self->{FH}->{$file}->open("<$file") || die "cannot open file $file\n";
	$self->{__XMLPARSER__} = new XML::Parser(Handlers => 
						 {Start => \&__XMLTagStart,
						  End => \&__XMLTagEnd});
	$self->{__XMLHANDLE__} = $self->{__XMLPARSER__}->parse_start;
    }

    my $fh=$self->{FH}->{$file};
    my $OldDel=$/;
    $/='>';
    while (<$fh>){
	eval { $self->{__XMLHANDLE__}->parse_more($_); };
	if ($@){
	    warn $@;
	    print STDERR $_;
	}
    }
    $/=$OldDel;
    $fh->close;

    my $srcid = $self->{__XMLHANDLE__}->{TREEBANKIDS}->[0];
    my $trgid = $self->{__XMLHANDLE__}->{TREEBANKIDS}->[1];

    my %attr=();
    $attr{-src_type}='TigerXML';
    $attr{-trg_type}='TigerXML';
    $attr{-src_file}=
	__find_corpus_file($self->{__XMLHANDLE__}->{TREEBANKS}->{$srcid},$file);
    $attr{-trg_file}=
	__find_corpus_file($self->{__XMLHANDLE__}->{TREEBANKS}->{$trgid},$file);

    $self->make_corpus_handles(%attr);

    return $self->{__XMLHANDLE__}->{LINKCOUNT};
}

sub __find_corpus_file{
    my ($file,$alignfile)=@_;
    return $file if (-e $file);
    my $dir = dirname($alignfile);
    return $dir.'/'.$file if (-e $dir.'/'.$file);
    my $base=basename($file);
    return $dir.'/'.$base if (-e $dir.'/'.$base);
    if ($file!~/\.gz$/){
	return __find_corpus_file($file.'.gz',$alignfile);
    }
    warn "cannot find file $file\n";
    return $file;
}



##-------------------------------------------------------------------------
## 

sub __XMLTagStart{
    my ($p,$e,%a)=@_;

    if ($e eq 'treebanks'){
	$p->{TREEBANKIDS}=[];
    }
    elsif ($e eq 'treebank'){
	$p->{TREEBANKS}->{$a{id}}=$a{filename};
	push (@{$p->{TREEBANKIDS}},$a{id});
    }
    elsif ($e eq 'align'){
	$p->{ALIGN}->{type}=$a{type};
	$p->{ALIGN}->{comment}=$a{comment};
    }
    elsif ($e eq 'node'){
	$p->{ALIGN}->{$a{treebank_id}}=$a{node_id}; # (always 1 node/id?)
    }
}

sub __XMLTagEnd{
    my ($p,$e)=@_;
    
    if ($e eq 'align'){
	# we assume that there are only two treebansk linked with each other
	my $src=$p->{ALIGN}->{$p->{TREEBANKIDS}->[0]};
	my $trg=$p->{ALIGN}->{$p->{TREEBANKIDS}->[1]};
	$p->{LINKS}->{$src}->{$trg}=$p->{ALIGN}->{type};
	$p->{LINKCOUNT}++;
	# assume that node IDs include sentence ID
	# assume also that there are only 1:1 sentence alignments
	my ($sid)=split(/\_/,$src);
	my ($tid)=split(/\_/,$trg);
	$p->{SALIGN}->{$sid}=$tid;
	$p->{TALIGN}->{$tid}=$sid;
    }
    elsif ($e eq 'treebanks'){
	$p->{NEWTREEBANKINFO}=1;
    }
}





1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

YADWA::Data::Aligned::STA - Perl extension for blah blah blah

=head1 SYNOPSIS

  use YADWA::Data::Aligned::STA;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for YADWA::Data::Aligned::STA, created by h2xs. It looks like the
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
