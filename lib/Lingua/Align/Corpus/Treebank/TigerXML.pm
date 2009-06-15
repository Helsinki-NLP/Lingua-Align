package Lingua::Align::Corpus::Treebank::TigerXML;

use 5.005;
use strict;
use Lingua::Align::Corpus::Treebank;



# TODO:
# - should I handle secondary edges?
#   (like I do something about re-entry indeces in AlpinoXML)



use vars qw($VERSION @ISA);
$VERSION = '0.01';
@ISA = qw(Lingua::Align::Corpus::Treebank);

use FileHandle;
use XML::Parser;


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


sub print_header{
    my $self=shift;
    my $str = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<corpus xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="TigerXML.xsd"
        id="Lingua::Align conversion">
  <head>
    <meta>
      <format></format>
      <name>testset</name>
      <author></author>
      <date></date>
      <description></description>
    </meta>
    <annotation>
';
    if (ref($self->{TFEATURES}) eq 'HASH'){
	foreach my $f (keys %{$self->{TFEATURES}}){
	    $str.="      <feature name=\"$f\" domain=\"T\" >\n";
	    foreach my $n (keys %{$self->{TFEATURES}->{$f}}){
		$str.="        <value name=\"$n\">";
		$str.="$self->{TFEATURES}->{$f}->{$n}</value>\n";
	    }
	    $str.="      </feature>\n";
	}
    }
    if (ref($self->{NTFEATURES}) eq 'HASH'){
	foreach my $f (keys %{$self->{NTFEATURES}}){
	    $str.="      <feature name=\"$f\" domain=\"NT\" >\n";
	    foreach my $n (keys %{$self->{NTFEATURES}->{$f}}){
		$str.="        <value name=\"$n\">";
		$str.="$self->{NTFEATURES}->{$f}->{$n}</value>\n";
	    }
	    $str.="      </feature>\n";
	}
    }
    $str.="    </annotation>\n   </head>\n  <body>\n";
    return $str;
}

sub print_tail{
    return '</body>
</corpus>
';
}

sub escape_string{
    my $string = shift;
    $string=~s/\&/&amp;/gs;
    $string=~s/\>/&gt;/gs;
    $string=~s/\</&lt;/gs;
    $string=~s/\"/&quot;/gs;
    return $string;
}

sub print_tree{
    my $self=shift;
    my $tree=shift;

    my $ids=shift || [];
    my $node = shift || $tree->{ROOTNODE};

    my $str='<s id="'.$tree->{ID}."\">\n";
    $str.='  <graph root="'.$node."\">\n";
    $str.="    <terminals>\n";
    foreach my $t (sort @{$tree->{TERMINALS}}){
	$str.= '      <t id="'.$t.'"';
	foreach my $k (keys %{$tree->{NODES}->{$t}}){
	    next if (ref($tree->{NODES}->{$t}->{$k}));
	    next if ($k eq 'id');
	    # save values for the header .... (if not word|lemma|root|..)
	    if ($k!~/(word|root|lemma|sense|id|begin|end|index)/i){
		$self->{TFEATURES}->{$k}->{$tree->{NODES}->{$t}->{$k}}='--';
	    }
	    else{$self->{NTFEATURES}->{$k}={};}
	    $tree->{NODES}->{$t}->{$k}=
		escape_string($tree->{NODES}->{$t}->{$k});
	    $str.= " $k=\"$tree->{NODES}->{$t}->{$k}\"";
	}
	$str.= " />\n";
    }
    $str.="    </terminals>\n    <nonterminals>\n";
    foreach my $n (keys %{$tree->{NODES}}){
	if ($n eq '4_22'){
	    print '';
	}
#	if (exists $tree->{NODES}->{$n}->{CHILDREN}){
	if ((exists $tree->{NODES}->{$n}->{CHILDREN}) || 
	    (exists $tree->{NODES}->{$n}->{CHILDREN2})){  # secondary edges ...
	    $str.= '      <nt id="'.$n.'"';

	    #---------------------------------------------------------
	    # if there is not category label: make one
	    # (stockholm tree aligner needs this .... (is this bad?)
	    if (not exists $tree->{NODES}->{$n}->{cat}){
		if (exists $tree->{NODES}->{$n}->{lcat}){
		    $tree->{NODES}->{$n}->{cat} = $tree->{NODES}->{$n}->{lcat};
		}
		if (exists $tree->{NODES}->{$n}->{index}){
		    $tree->{NODES}->{$n}->{cat}=
			'[idx'.$tree->{NODES}->{$n}->{index}.']';
		}
		else{
		    $tree->{NODES}->{$n}->{cat} = '--';
		}
	    }
	    #---------------------------------------------------------


	    foreach my $k (keys %{$tree->{NODES}->{$n}}){
		next if (ref($tree->{NODES}->{$n}->{$k}));
		next if ($k eq 'id');
		# save values for the header ....
		if ($k!~/(word|root|lemma|sense|id|begin|end|index)/i){
		    $self->{NTFEATURES}->{$k}->{$tree->{NODES}->{$n}->{$k}}='--';
		}
		else{$self->{NTFEATURES}->{$k}={};}
		$tree->{NODES}->{$n}->{$k}=
		    escape_string($tree->{NODES}->{$n}->{$k});
		$str.= " $k=\"$tree->{NODES}->{$n}->{$k}\"";
	    }
	    $str.= " >\n";

	    if (exists $tree->{NODES}->{$n}->{CHILDREN}){
		for my $c (0..$#{$tree->{NODES}->{$n}->{CHILDREN}}){
		    $str.='        <edge idref="';
		    $str.=$tree->{NODES}->{$n}->{CHILDREN}->[$c];
		    $str.='" label="';
		    my $label =
			escape_string($tree->{NODES}->{$n}->{RELATION}->[$c]);
		    $str.=$label;
		    $str.="\" />\n";
		    # save values for the header ....
		    $self->{LABELS}->{$label}='--';
		}
	    }
	    if (exists $tree->{NODES}->{$n}->{CHILDREN2}){
		for my $c (0..$#{$tree->{NODES}->{$n}->{CHILDREN2}}){
		    $str.='        <edge idref="';
		    $str.=$tree->{NODES}->{$n}->{CHILDREN2}->[$c];
		    $str.='" label="';
		    my $label =
			escape_string($tree->{NODES}->{$n}->{RELATION2}->[$c]);
		$str.=$label;
		    $str.="\" />\n";
		    # save values for the header ....
		    $self->{LABELS}->{$label}='--';
		}
	    }


	    $str.= "      </nt>\n";
	}
    }
    $str.="    </nonterminals>\n  </graph>\n</s>\n";
    return $str;
}


# go to a specific sentence ID
# right now: only sequential readin is allowed!
# --> if already open: close file and restart reading
# better -> we should do some indexing
# but: problem with gzipped files!


sub go_to{
    my $self=shift;
    my $sentID=shift;

    if (not $sentID){
	print STDERR "Don't know where to go to! Specify a sentence ID!\n";
	return 0;
    }

    my $file=shift || $self->{-file};
    if (defined $self->{FH}->{$file}){
	$self->{SRC}->close();
    }
    $self->{LAST_TREE}={};
    while ($self->next_sentence($self->{LAST_TREE}={})){
	return 1 if ($self->{LAST_TREE}->{ID} eq $sentID);
    }

    print STDERR "Could not find sentence $sentID? What can I do?\n";
    return 0;

}


sub next_tree{
    my $self=shift;
    return $self->next_sentence(@_);
}

sub read_next_sentence{
    my $self=shift;
    my $tree=shift;

    my $file=shift || $self->{-file};
    if (! defined $self->{FH}->{$file}){
	$self->{FH}->{$file} = new FileHandle;
	$self->{FH}->{$file}->open("<$file") || die "cannot open file $file\n";
	$self->{__XMLPARSER__} = new XML::Parser(Handlers => 
						 {Start => \&__XMLTagStart,
						  End => \&__XMLTagEnd});
	$self->{__XMLHANDLE__} = $self->{__XMLPARSER__}->parse_start;
    }

    $self->{__XMLHANDLE__}->{SENTID}=undef;
    $self->{__XMLHANDLE__}->{SENT_ENDED}=0;

    my $fh=$self->{FH}->{$file};
    my $OldDel=$/;
    $/='>';
    while (<$fh>){
	eval { $self->{__XMLHANDLE__}->parse_more($_); };
	if ($@){
	    warn $@;
	    print STDERR $_;
	}
	last if ($self->{__XMLHANDLE__}->{SENT_ENDED});
    }
    $/=$OldDel;
    if (defined $self->{__XMLHANDLE__}->{SENTID}){
	$tree->{ROOTNODE}=$self->{__XMLHANDLE__}->{ROOTNODE};
	$tree->{NODES}=$self->{__XMLHANDLE__}->{NODES};
	$tree->{TERMINALS}=$self->{__XMLHANDLE__}->{TERMINALS};
	$tree->{ID}=$self->{__XMLHANDLE__}->{SENTID};
	return 1;
    }
    $self->close_file($file);
#    $fh->close;
    return 0;
}





##-------------------------------------------------------------------------
## 

sub __XMLTagStart{
    my ($p,$e,%a)=@_;

    if ($e eq 's'){
	$p->{SENT}=1;
	$p->{SENTID}=$a{id};
	$p->{NODES}={};        # need better clean-up?! (memory leak?)
	$p->{TERMINALS}=[];
    }
    elsif ($e eq 't'){
	push(@{$p->{TERMINALS}},$a{id});
	foreach (keys %a){
	    $p->{NODES}->{$a{id}}->{$_}=$a{$_};
	}
    }
    elsif ($e eq 'nt'){
	foreach (keys %a){
	    $p->{NODES}->{$a{id}}->{$_}=$a{$_};
	}
	$p->{CURRENT}=$a{id};
    }
    elsif ($e eq 'edge'){
	my $parent=$p->{CURRENT};
	my $child=$a{idref};
	my $rel=$a{label};
        # do I have to allow multiple parents? (->secondary edges?!)
	push(@{$p->{NODES}->{$child}->{PARENTS}},$parent);
	push(@{$p->{NODES}->{$parent}->{CHILDREN}},$child);
# 	push(@{$p->{NODES}->{$child}->{RELATION}},$rel);
	push(@{$p->{NODES}->{$parent}->{RELATION}},$rel);
#	$p->{REL}->{$child}->{$parent}=$rel;
#	$p->{REL}->{$parent}->{$child}=$rel;
    }
    elsif ($e eq 'graph'){
	$p->{ROOTNODE}=$a{root};
    }
}

sub __XMLTagEnd{
    my ($p,$e)=@_;

    if ($e eq 's'){
	$p->{SENT_ENDED}=1;
    }
}





# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

YADWA::Data::Trees::TigerXML - Perl extension for blah blah blah

=head1 SYNOPSIS

  use YADWA::Data::Trees::TigerXML;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for YADWA::Data::Trees::TigerXML, created by h2xs. It looks like the
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
