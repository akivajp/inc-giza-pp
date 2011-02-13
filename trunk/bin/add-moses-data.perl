#!/usr/bin/perl -w

use FindBin qw($Bin); #gives full path of this script
use strict;
use XMLRPC::Lite;
use Encode;

my $dataDir = "/home/abby/mt-systems/fr-en/data";
my $vocabDir = $dataDir . "/vocab";
my $newDir = $dataDir . "/new";
my $SCRIPTS_ROOTDIR = $ENV{"SCRIPTS_ROOTDIR"} if defined($ENV{"SCRIPTS_ROOTDIR"});
my @files = </home/abby/mt-systems/fr-en/data/new/fr/*>;
my $noFiles = scalar(@files);
if($noFiles == 0) { 
  print "No new data\n";
  exit(); 
}
##TOKENIZE
system("cat $newDir/fr/* > $newDir/new.txt; rm -f $newDir/fr/*");
system("cat $newDir/new.txt | $SCRIPTS_ROOTDIR/tokenizer/tokenizer.perl | $SCRIPTS_ROOTDIR/tokenizer/lowercase.perl > $newDir/fr/new.txt");
system("cat $newDir/en/* > $newDir/new.txt; rm -f $newDir/en/*");
system("cat $newDir/new.txt | $SCRIPTS_ROOTDIR/tokenizer/tokenizer.perl | $SCRIPTS_ROOTDIR/tokenizer/lowercase.perl > $newDir/en/new.txt");
system("rm $newDir/new.txt");

#PASS TO PREPROCESSOR
factorize($newDir);
##VOCAB
my $source = $newDir . "/fr/fr";
my $target = $newDir . "/en/en";
print $source."\n".$target."\n"; 
my $src_vcb = $vocabDir . "/ep.fr.vcb";
my $trg_vcb = $vocabDir . "/ep.en.vcb";
##get vocab for new bitext
my $plain2snt = "/home/abby/giza-inc/GIZA++-v2/plain2snt.out";
print "$plain2snt $source $target -txt1-vocab $src_vcb -txt2-vocab $trg_vcb\n";
system("$plain2snt $source $target -txt1-vocab $src_vcb -txt2-vocab $trg_vcb");
##copy new vocab back and make backup 
system("mv $source.vcb $src_vcb");
system("mv $target.vcb $trg_vcb");
#system("cp /home/abby/mt-systems/fr-en/data/vocab/*.vcb /home/abby/mt-systems/fr-en/data/backup/");

##COOCURRENCE
my $snt2cooc = "/home/abby/giza-inc/GIZA++-v2/snt2cooc.out";
my $src2trgCooc = "fr-en.cooc";
my $trg2srcCooc = "en-fr.cooc";
my $src2trgSnt = $source . "_en.snt";
my $trg2srcSnt = $target . "_fr.snt";
my $s2tCoocCmd = "$snt2cooc $src_vcb $trg_vcb $src2trgSnt $vocabDir/$src2trgCooc > ./$src2trgCooc";
my $t2sCoocCmd = "$snt2cooc $trg_vcb $src_vcb $trg2srcSnt $vocabDir/$trg2srcCooc > ./$trg2srcCooc";
print "executing \"" . $s2tCoocCmd . "\"\n";
system($s2tCoocCmd);
print "executing \"" . $t2sCoocCmd . "\"\n";
system($t2sCoocCmd);
system("mv $src2trgCooc $trg2srcCooc $vocabDir/");

##RUN GIZA
my $gizaPrg = "/home/abby/giza-inc/GIZA++-v2/GIZA++";
my $statsDir = "/home/abby/mt-systems/fr-en/giza-prbs";
my $dConfig = $statsDir . "/en-fr.config";
my $iConfig = $statsDir . "/fr-en.config";
system("$gizaPrg $dConfig");
system("$gizaPrg $iConfig");
##ALIGN WORDS 
my $symalDir = $SCRIPTS_ROOTDIR. "/training/symal";
my $fAlign = $newDir . "/alignments";
#system("gzip $statsDir/*.Ahmm.10");
my $dAlign = $statsDir . "/tmp/en-fr.Ahmm.10";
my $iAlign = $statsDir . "/tmp/fr-en.Ahmm.10";
#my $alignData = "-d \"echo '$str1'\" -i \"echo '$str2'\""; 
my $alignData = "-d \"cat $dAlign\" -i \"cat $iAlign\"";
my $alignHeurs = "-alignment=\"grow\" -diagonal=\"yes\" -final=\"yes\" -both=\"yes\""; 
system("$symalDir/giza2bal.pl $alignData | $symalDir/symal $alignHeurs > $fAlign");

##PASS NEW BITEXT TO ONLINE MOSES
#connect
my $url = "http://localhost:8084/RPC2";
my $proxy = XMLRPC::Lite->proxy($url);
my $enc = find_encoding('latin1');

#open all files and pass sentence by sentence for now
my $f1;
my $f2;
my $f3;
open(SRC, "<:utf8", $source);
open(TRG, "<:utf8", $target);
open(ALG, "<:utf8", $fAlign);
while($f1 = <SRC>) {
  $f2 = <TRG>;
  $f3 = <ALG>;
  chomp($f1);
  chomp($f2);
  chomp($f3);
  my $srcParam = SOAP::Data->type(string => Encode::encode($enc->name, $f1));
  my $targetParam = SOAP::Data->type(string => Encode::encode($enc->name, $f2));
  my $alignParam = SOAP::Data->type(string => Encode::encode($enc->name, $f3));
  #pass to moses updater
  my %params = ();
  %params = ("source" => $srcParam, "target" => $targetParam, "alignment" => $alignParam);
  my $mosesResult = $proxy->call("updater",\%params)->result;
  #print "source = \"" . $f1. "\"\ntarget = \"" . $f2. "\"\nalignment = \"" . $f3 . "\"\n";
}
close(SRC);
close(TRG);
close(ALG);

##ADD NEW DATA TO SOURCE, TARGET, ALIGNMENTS FOR BACKUPS
system("cat $source >> /home/abby/mt-systems/fr-en/tm/french");
system("cat $target >> /home/abby/mt-systems/fr-en/tm/english");
system("cat $fAlign >> /home/abby/mt-systems/fr-en/tm/alignments");

#REMOVE ALL DATA
system("rm $newDir/en/* $newDir/fr/*");

sub factorize {
  my ($dir) = @_;
  system("java -cp `echo ls /home/niraj/work/gate/lib/*.jar | tr ' ' ':'`:`echo ls /home/niraj/work/gate/bin/*.jar | tr ' ' ':'`:/home/niraj/work/javautils/ Preprocess /home/server/work/gate-applications/annie-morph.xgapp  $dir/en  $dir/fr $dir/en/en $dir/fr/fr");
}
