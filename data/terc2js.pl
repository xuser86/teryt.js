#!/usr/bin/perl

# perl terc2js.pl > terc.db.js

# -----------------------------------------------------------------------------
 
use XML::Simple;
use Data::Dumper;

use strict;
use warnings;
use utf8;

use open ':std', ':encoding(UTF-8)';

# -----------------------------------------------------------------------------

sub GetTerc {
	my ($xmlfile) = @_;
	
	my $ref = XMLin($xmlfile);
	
	my %nazwydod = ();
	my %rodzH = ();
	my %outH = ();
	
	foreach my $r (@{$ref->{'catalog'}{'row'}}) {
		#print Dumper($r); 
		$r = $r->{'col'};
		
		my ($id,$nazwa,$woj,$pow,$gmin,$rodz,$nazdod) = ('','','','','','','');
		
		$nazwa = $r->{'NAZWA'}{'content'} if($r->{'NAZWA'}{'content'});
		$woj = $r->{'WOJ'}{'content'} if($r->{'WOJ'}{'content'});
		$pow = $r->{'POW'}{'content'} if($r->{'POW'}{'content'});
		$gmin = $r->{'GMI'}{'content'} if($r->{'GMI'}{'content'});
		$rodz = $r->{'RODZ'}{'content'} if($r->{'RODZ'}{'content'});
		
		$id = $woj.$pow.$gmin.$rodz;
		
		$gmin = $woj.$pow.$gmin if($gmin);
		$pow = $woj.$pow if($pow);
		
		
		$nazdod = $r->{'NAZDOD'}{'content'} if($r->{'NAZDOD'}{'content'});
		
		if( defined $nazwydod{$nazdod} and $nazwydod{$nazdod} ne $rodz ) {
		    print $nazwydod{$nazdod}." ".$rodz."\n";
		}


		$nazwydod{$nazdod} = $rodz;
		$rodzH{$rodz} = 1;

		if( !defined $outH{$id} ) {
		    $outH{$id} = {
			'id'=>$id,
			'nazwa'=>$nazwa,
			'wojewodztwo'=>$woj,
			'powiat'=>$pow,
			'gmina'=>$gmin,
			'rodzaj'=>$rodz,
			'nazwa_dod'=>$nazdod
		    };

		    #print $outH{$id}{'id'}." ";

		} else {
		    my $dbl = {
			'id'=>$id,
			'nazwa'=>$nazwa,
			'wojewodztwo'=>$woj,
			'powiat'=>$pow,
			'gmina'=>$gmin,
			'rodzaj'=>$rodz,
			'nazwa_dod'=>$nazdod
		    };

		    print "--------------------------------------\n";
		    print Dumper($outH{$id})."\n";
		    print Dumper($dbl)."\n";
		}
	}

	my $cur_rodz = -1;
	
	foreach my $o (keys %outH) {	
	    my $hashH = $outH{$o};

	    if( $hashH->{'nazwa_dod'} eq "miasto sto\x{142}eczne, na prawach powiatu" ) {
		$hashH->{'nazwa_dod'} = 'miasto na prawach powiatu';
	    }
	    if( $hashH->{'nazwa_dod'} eq "gmina miejska, miasto sto\x{142}eczne" ) {
		$hashH->{'nazwa_dod'} = 'gmina miejska';
	    }		    
	    
	    my $id_rodzaj = $nazwydod{ $hashH->{'nazwa_dod'} };

	    if( !$id_rodzaj ) {
		$nazwydod{ $hashH->{'nazwa_dod'} } = $cur_rodz;
		$id_rodzaj = $cur_rodz;
		$cur_rodz --;
	    }

	    if( $id_rodzaj < 0 ) {
		$outH{$o}{'rodzaj'} = $nazwydod{ $hashH->{'nazwa_dod'} };
	    }
	}
	

	#print Dumper(\%nazwydod);

	return (\%outH, \%nazwydod );
}

# -----------------------------------------------------------------------------

=begin

gmina

	'powiat' => '01',
	'wojewodztwo' => '06',
	'nazwa' => 'Terespol',
	'gmina' => '02',
	'nazwa_dod' => 'gmina miejska',
	'id' => '0601021',
	'rodzaj' => '1'
	
powiat
	
	'wojewodztwo' => '32',
	'rodzaj' => -1,
	'id' => '3214',
	'nazwa' => 'stargardzki',
	'gmina' => '',
	'nazwa_dod' => 'powiat',
	'powiat' => '3214'

wojewodztwo

	'wojewodztwo' => '02',
	'id' => '02',
	'rodzaj' => -2,
	'nazwa' => "DOLNO\x{15a}L\x{104}SKIE",
	'powiat' => '',
	'nazwa_dod' => "wojew\x{f3}dztwo",
	'gmina' => ''

	
=cut

# -----------------------------------------------------------------------------

# XML do pozyskania na http://www.stat.gov.pl/broker/access/prefile/listPreFiles.jspa

my ($tercH, $slnd) = GetTerc('TERC_20170102.xml');

my $wojewodztwa = {};
my $powiaty = {};
my $gminy = {};
my $gminyPoNazwie = {};

foreach my $id (keys %{$tercH}) {
    # print "$id\n";
    
    my $terc = $tercH->{$id};
    
    if ( length($id) == 2 ) {
	$wojewodztwa->{$id} = {
	    'wojewodztwo' => $id,
	    'nazwa' => $terc->{'nazwa'}
	}
    } elsif ( length($id) == 4 ) {
	$powiaty->{$id} = {
	    'wojewodztwo' => $terc->{'wojewodztwo'},
	    'powiat' => $id,
	    'nazwa' => $terc->{'nazwa'}
	}
    } elsif ( length($terc->{'gmina'}) == 6 ) {
	$gminy->{$terc->{'gmina'}}{'wojewodztwo'} = $terc->{'wojewodztwo'};
	$gminy->{$terc->{'gmina'}}{'powiat'} = $terc->{'powiat'};
	$gminy->{$terc->{'gmina'}}{'gmina'} = $terc->{'gmina'};
	$gminy->{$terc->{'gmina'}}{'nazwa'} = $terc->{'nazwa'};
	
	if ($terc->{'rodzaj'} < 4 || !defined $gminy->{$terc->{'gmina'}}{'rodzaj'}) {
	    $gminy->{$terc->{'gmina'}}{'rodzaj'} = $terc->{'nazwa_dod'}; # $terc->{'rodzaj'}
	}
	
	if (!defined $gminyPoNazwie->{$terc->{'powiat'}}{$terc->{'nazwa'}}) {
	    $gminyPoNazwie->{$terc->{'powiat'}}{$terc->{'nazwa'}} = [];
	}
	
	if ($terc->{'rodzaj'} < 4) {
	    push @{$gminyPoNazwie->{$terc->{'powiat'}}{$terc->{'nazwa'}}}, $terc->{'gmina'};
	    
	    if (@{$gminyPoNazwie->{$terc->{'powiat'}}{$terc->{'nazwa'}}} > 1) {
		foreach my $gmina1 (@{$gminyPoNazwie->{$terc->{'powiat'}}{$terc->{'nazwa'}}}) {
		    $gminy->{$gmina1}{'wymagany'} = 1;
		}
	    }
	}
    }
}

print "var terc = {};\n\n";

foreach my $id_wojewodztwo (sort keys %{$wojewodztwa}) {
    my $nazwa = $wojewodztwa->{$id_wojewodztwo}{'nazwa'};

    print "terc['$id_wojewodztwo'] = {id:'$id_wojewodztwo', nazwa:'$nazwa', powiaty:{}};\n";
}

print "\n";

foreach my $id_powiat (sort keys %{$powiaty}) {
    my $id_wojewodztwo = $powiaty->{$id_powiat}{'wojewodztwo'};
    my $nazwa = $powiaty->{$id_powiat}{'nazwa'};

    print "terc['$id_wojewodztwo'].powiaty['$id_powiat'] = {id:'$id_powiat', nazwa:'$nazwa', gminy:{}};\n";
}

print "\n";

foreach my $id_gmina (sort keys %{$gminy}) {
    my $id_powiat = $gminy->{$id_gmina}{'powiat'};
    my $id_wojewodztwo = $gminy->{$id_gmina}{'wojewodztwo'};
    my $nazwa = $gminy->{$id_gmina}{'nazwa'};
    my $rodzaj = $gminy->{$id_gmina}{'rodzaj'};
    my $wymagany =  $gminy->{$id_gmina}{'wymagany'};
    
    if ($wymagany) { 
	print "terc['$id_wojewodztwo'].powiaty['$id_powiat'].gminy['$id_gmina'] = {id:'$id_gmina', nazwa:'$nazwa ($rodzaj)'};\n";
    } else {
	print "terc['$id_wojewodztwo'].powiaty['$id_powiat'].gminy['$id_gmina'] = {id:'$id_gmina', nazwa:'$nazwa'};\n";
    }
}

print "\n";

# -----------------------------------------------------------------------------
