Incremental word alignments for SMT using online EM.
Currently supports IBM Model 1 and HMM-based word
alignments.

Supports disk-based incremental alignments (main.cpp.org / Makefile.org)
or server/client calls via XMLRPC (main.cpp.xmlrpc / Makefile.xmlrpc).
See the toy/ folder for example configuration files for
both disk-based and RPC style updates.

To use inc-giza-pp to align new parallel sentence pairs using
online EM you must do the following:

  1. Get and compile inc-giza-pp from http://code.google.com/p/inc-giza-pp/
  1. Train a seed model using inc-giza-pp. Currently only supports model1and the hmm-based word alignments. Save the output from the last iteration. (**Note**: the output is specially formatted and differs from batch Giza.)
  1. When you have new sentences to align you must first:
    * update the vocab with any new source and target words (plain2snt.out)
    * update the cooccurrence files with word pairs (snt2cooc.out)
  1. Pass in the new sentences along with the previous word translation and alignment parameters from the last iteration.