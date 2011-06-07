#!/usr/bin/perl -w

use FindBin qw($Bin); #gives full path of this script
use strict;
use DBI;
use DBD::mysql;
use XMLRPC::Lite;
use Encode;

my $db = "abbytool_development";
my $user = "ruby";
my $pass = "rail";

my $argc = scalar(@ARGV);
die "Need 3 source, target, oldTranslation" unless $argc == 0;
#print $ARGV[0]."\n"; 
my $source = "dies ist frein satz";
my $target = "this is a sentence";
my $oldTranslation = "this is an sentence";

my $gizaUrl = "http://localhost:8090/RPC2";
my $gizaProxy = XMLRPC::Lite->proxy($gizaUrl);

my $srcParam = SOAP::Data->type(string => Encode::encode("iso-8859-1", $source));
my $targetParam = SOAP::Data->type(string => Encode::encode("iso-8859-1", $target));
my $oldTransParam = SOAP::Data->type(string => Encode::encode("iso-8859-1", $oldTranslation));

#get alignment
my %params = ("source" => $srcParam, "target" => $targetParam, "oldTranslation" => $oldTransParam);
my $gizaResult = $gizaProxy->call("remoteAlign",\%params)->result;
print $gizaResult->{'alignment'};

###get inverted alignment
%params = ();
my $gizaInvUrl = "http://localhost:8091/RPC2";
my $gizaInvProxy = XMLRPC::Lite->proxy($gizaInvUrl);
%params = ("source" => $targetParam, "target" => $source);
my $gizaInvResult = $gizaInvProxy->call("remoteAlign",\%params)->result;
print $gizaInvResult->{'alignment'};
#
##pass to word aligner 
my $str1 = $gizaResult->{'alignment'};
my $str2 = $gizaInvResult->{'alignment'};
my $alignData = "-d \"echo '$str1'\" -i \"echo '$str2'\""; 
my $alignHeurs = "-alignment=\"grow\" -diagonal=\"yes\" -final=\"yes\" -both=\"yes\""; 
open(ALIGNED, "$Bin/support/giza2bal.pl $alignData | $Bin/support/symal $alignHeurs |");
my $symal = <ALIGNED>;
close(ALIGNED);
print $symal;
#
##pass to moses updater
#%params = ();
#my $url = "http://localhost:8085/RPC2";
#my $proxy = XMLRPC::Lite->proxy($url);
#%params = ("source" => $srcParam, "target" => $targetParam, "oldTranslation" => $oldTransParam, "alignment" => $symal);
#my $mosesResult = $proxy->call("updater",\%params)->result;

#....?
sub connect {
  return DBI->connect("DBI:mysql:database=".$db.";host=localhost", $user, $pass);
}
