#--------------------------------------------------------------------------
# jorg.tiedemann@lingil.uu.se				May 2010
#
# run tree alignment experiments with the SMULTRON treebank
# (this is mainly for testing the aligner aand different settings)
#
# Note that Moses/Giza++ features are only derived from the small
# data set provided by SMULTRON sub corpora! 
# --> run word alignment on larger data sets for more reliable features!
#
# This should run on standard linux.i686 systems.
# For Mac OSX on Intel machines: set "-c megam.osx" in TREEALIGN (see below)
#--------------------------------------------------------------------------
#
#
# Exampels:
#--------------------------------------------------------------------------
# make sophie ....... run training and alignment on Sophie's World
# make FEAT=catpos .. run the same with only the "catpos" feature
# eval .............. evaluate alignments from the "sophie" alignments
#
#
# Cross-domain experiments: 
# (train in one domain and align another one)
#--------------------------------------------------------------------------
# make cross-eco-sophie... make & evaluate eco-alignments done with sophie model
# make cross-sophie-eco... make & evaluate sophie-alignments done with eco model
#
#
# Tests with other feature sets (on Sophie's World):
#--------------------------------------------------------------------------
# make test-no-moses1 .... use a model without Moses/Giza++ features
# make test-no-moses2 .... use a model without Moses/Giza++ features but 
#                          with co-occurrence features (Dice scores)
# make test-dice ......... use only co-occurrence features (Dice scores)
#                          (Note that Dice scores are not very reliable
#                           either because they are also computed on the small
#                           Sophie's World corpus only!)
#
#--------------------------------------------------------------------------



#--------------------------------------------------------------------------
# path to the tree aligner scripts
#--------------------------------------------------------------------------

TREEALIGNERHOME = ..
TREEALIGN       = ${TREEALIGNERHOME}/bin/treealign
STA2MOSES       = ${TREEALIGNERHOME}/bin/sta2moses
ALIGNEVAL       = ${TREEALIGNERHOME}/bin/treealigneval

# uncomment the following line if you want to run the TreeAligner on Mac OSX:
# TREEALIGN     = ${TREEALIGNERHOME}/bin/treealign -c megam.osx



#--------------------------------------------------------------------------
# location of the SMULTRON treebank
# download from  http://kitt.cl.uzh.ch/kitt/smultron/
#       info at  http://www.ling.su.se/DaLi/research/smultron
#--------------------------------------------------------------------------

SMULTRON    = smultron-2.0
SOPHIE      = alignments_sophie_en_sv
SOPHIE_DEEN = alignments_sophie_de_sv
ECO         = alignments_economy_en_sv
DVDMAN      = alignments_dvdman_en_sv

# old SMULTRON version:
#
# SOPHIE      = Alignments_SMULTRON_Sophies_World_SV_EN
# SOPHIE_DEEN = Alignments_SMULTRON_Sophies_World_DE_EN
# ECO         = Alignments_SMULTRON_Economy_Texts_SV_EN

TRAINCORPUS = ${SMULTRON}/${SOPHIE}


#--------------------------------------------------------------------------
# now some important tree aligner parameters:
#
# FEAT ......... specifies the features to be used for alignment
#                (more info: perldoc  ../lib/Lingua/Align/Features.pm)
# ALIGNTHR ..... alignment score threshold
# EXTRAOPT ..... extra options (like -C -U for adding history features)
# CLASSIFIER ... external classifier to be used (only megam is really supported)
# WEIGHTG ...... weight for positive training examples from "good" links
# WEIGHTP ...... weight for positive training examples from "possible" links
# WEIGHTN ...... weight for negative training examples
#--------------------------------------------------------------------------

FEAT = 'nrleafsratio:parent_catpos:catpos.parent_catpos:treelevelsim:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:children_giza.catpos'

# other features you might want to use:
#
# inside4:outside4:inside4*outside4:parent_inside4:
# insideST4:insideTS4:maxinsideST:maxinsideTS:inside4*parent_inside4:
# treelevelsim*inside4:maxinside.catpos


ALIGNTHR     = 0.1
# EXTRAOPT   = -C -U
CLASSIFIER   = megam
# MEGAMARGS  = -maxi 50 -tune

WEIGHTG=3
WEIGHTP=1
WEIGHTN=1

#--------------------------------------------------------------------------
# ALIGN is the basic alignment strategy
# - inference refers to the two-step strategy: 1) classification 
#                                              2) alignment inference (search)
# - bottom-up refers to greedy bottom-up linking using classifier decision
#   (final step: align nodes that have not been linked yet using link search)
#--------------------------------------------------------------------------

# ALIGN       = bottom-up
ALIGN         = inference

#--------------------------------------------------------------------------
# SEARCH is the alignment inference algorithm that is used after 
# local classification. Lot's of different search strategies are possible
#--------------------------------------------------------------------------

SEARCH = wellformed
# SEARCH = greedy
# SEARCH = assign
#
# some examples of complex search strategies with various alignment steps:
#--------------------------------------------------------------------------
# 1) GreedyWeaklyWellformedFinal
#	greedy search, 
#       check for weak wellformedness, 
#       add n:m links in a second (final) step
# 2) GreedyWeaklyWellformedFinalNTfirst
#       align NT nodes before terminals with "GreedyWeaklyWellformed"
#       add n:m links with the same strategy (NT first + GreedyWeaklyWellformed)
# 3) NTfirstGreedyWeaklyWellformedFinal
#       align NT nodes first with "GreedyWeaklyWellformedFinal"
#       align terminals afterwards also with "GreedyWeaklyWellformedFinal"
#




#-------------------------------------------------------------------------
# for evaluation: 
#
# nr sentences used for training and testing
# STARTEVAL: gives first sentID that will be aligned (for evaluation!)
# ENDEVAL: gives last sentID that will be aligned (for evaluation!)
#-------------------------------------------------------------------------

NR_TRAIN  = 100
STARTEVAL = 105

# NR_TEST = 100
# ENDEVAL = 209

# big value --> use all remaining sentences for testing!

NR_TEST = 10000
ENDEVAL = 10000




#-------------------------------------------------------------------------
# MOSES is needed if you have to make the word alignment features
# (giza, gizae2f, gizaf2e, moses, inside, outside, ...)
#
# MOSESTRAINING .... training script for moses
# MOSES_SYM ........ word alignment symmetrization heuristics
#-------------------------------------------------------------------------

MOSESTRAINING = ${SCRIPTS_ROOTDIR}/training
MOSES_SYM     = intersect
# MOSES_SYM   = grow-diag-final-and

SRC=src
TRG=trg



###########################################################################
###########################################################################
#
# Experiments:
#
# sophie ........... run training and alignment on Sophie's World
# eval ............. evaluate alignments from the "sophie" alignments
# eco .............. run training and alignment on Economy text
# dvd .............. run training and alignment on DVDman
# cross-eco-sophie.. evaluate eco-alignments done with sophie model
# cross-sophie-eco.. evaluate sophie-alignments done with eco model
# cross-dvd-sophie.. evaluate dvd-alignments done with sophie model
# cross-sophie-dvd.. evaluate sophie-alignments done with dvd model
# cross-dvd-eco .... evaluate dvd-alignments done with eco model
# cross-eco-dvd .... evaluate eco-alignments done with dvd model
#
###########################################################################
###########################################################################


all: sophie

# train model on NR_TRAIN sentences and align the following NR_TEST sentences
# (deletes previous alignment results!!!!!)

sophie: 
	rm -f sophie.alg
	make sophie.alg
	make eval

sophie.alg: moses-sophie
	${TREEALIGN} \
		-a ${SMULTRON}/${SOPHIE}.xml \
		-M $< \
		-o '${MEGAMARGS}' \
		-b ${ALIGN} \
		-f ${FEAT} \
		-n ${NR_TRAIN} \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-1 ${WEIGHTG} \
		-2 ${WEIGHTP} \
		-3 ${WEIGHTN} \
		-N -L -v \
		-l ${SEARCH} ${EXTRAOPT} > $@

eval: sophie.alg
	${ALIGNEVAL} -b ${STARTEVAL} -e ${ENDEVAL} \
		${SMULTRON}/${SOPHIE}.xml $<



# run on economy texts

eco: 
	rm -f eco.alg
	make eco.alg
	make eco.eval

eco.alg: moses-eco
	${TREEALIGN} \
		-a ${SMULTRON}/${ECO}.xml \
		-M $< \
		-o '${MEGAMARGS}' \
		-b ${ALIGN} \
		-f ${FEAT} \
		-n ${NR_TRAIN} \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-1 ${WEIGHTG} \
		-2 ${WEIGHTP} \
		-3 ${WEIGHTN} \
		-N -L -v \
		-l ${SEARCH} ${EXTRAOPT} > $@

eco.eval: eco.alg
	${ALIGNEVAL} ${SMULTRON}/${ECO}.xml $<


# run on DVDman

dvd: 
	rm -f dvd.alg
	make dvd.alg
	make dvd.eval

dvd.alg: moses-dvd
	${TREEALIGN} \
		-a ${SMULTRON}/${DVDMAN}.xml \
		-M $< \
		-o '${MEGAMARGS}' \
		-b ${ALIGN} \
		-f ${FEAT} \
		-n ${NR_TRAIN} \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-1 ${WEIGHTG} \
		-2 ${WEIGHTP} \
		-3 ${WEIGHTN} \
		-N -L -v \
		-l ${SEARCH} ${EXTRAOPT} > $@

dvd.eval: eco.alg
	${ALIGNEVAL} ${SMULTRON}/${DVDMAN}.xml $<




#-------------------------------------------------------------------------
# run cross-domain experiments for all possible domain combinations!
#
# cross-big = train on all data in one domain and align another
# cross-all = train on NR_TRAIN sentences in one domain & align another
#             (default = 100 ---> comparable with in-domain experiments!)
#-------------------------------------------------------------------------

cross-big:
	make NR_TRAIN=10000 cross-all

cross-all: 	cross-sophie-eco cross-eco-sophie \
		cross-sophie-dvd cross-dvd-sophie \
		cross-eco-dvd cross-dvd-eco


# train on sophie & align eco
cross-sophie-eco:
	make 	TRAINNAME=sophie TRAINALG=${SOPHIE} \
		TESTNAME=eco TESTALG=${ECO} \
		STARTEVAL=104 \
		cross-sophie-eco.eval

cross-eco-sophie:
	make 	TRAINNAME=eco TRAINALG=${ECO} \
		TESTNAME=sophie TESTALG=${SOPHIE} \
		STARTEVAL=105 \
		cross-eco-sophie.eval

cross-dvd-sophie:
	make 	TRAINNAME=dvd TRAINALG=${DVDMAN} \
		TESTNAME=sophie TESTALG=${SOPHIE} \
		STARTEVAL=105 \
		cross-dvd-sophie.eval

cross-sophie-dvd:
	make 	TRAINNAME=sophie TRAINALG=${SOPHIE} \
		TESTNAME=dvd TESTALG=${DVDMAN} \
		STARTEVAL=109 \
		cross-sophie-dvd.eval

cross-dvd-eco:
	make 	TRAINNAME=dvd TRAINALG=${DVDMAN} \
		TESTNAME=eco TESTALG=${ECO} \
		STARTEVAL=105 \
		cross-dvd-eco.eval

cross-eco-dvd:
	make 	TRAINNAME=eco TRAINALG=${ECO} \
		TESTNAME=dvd TESTALG=${DVDMAN} \
		STARTEVAL=109 \
		cross-eco-dvd.eval




%.eval: %.align
	${ALIGNEVAL} -b ${STARTEVAL} ${SMULTRON}/${TESTALG}.xml $< > $@

cross-${TRAINNAME}-${TESTNAME}.align: 	${TRAINNAME}${NR_TRAIN}.model \
					moses-${TESTNAME}
	${TREEALIGN} \
		-a ${SMULTRON}/${TESTALG}.xml \
		-M moses-${TESTNAME} \
		-m ${TRAINNAME}${NR_TRAIN}.model \
		-f ${FEAT} \
		-x ${ALIGNTHR} \
		-1 ${WEIGHTG} \
		-2 ${WEIGHTP} \
		-3 ${WEIGHTN} \
		-N -L -v \
		-l ${SEARCH} ${EXTRAOPT} > $@


${TRAINNAME}${NR_TRAIN}.model: moses-${TRAINNAME}
	rm -f $@
	${TREEALIGN} \
		-a ${SMULTRON}/${TRAINALG}.xml \
		-M $< \
		-m $@ \
		-e 0 \
		-n ${NR_TRAIN} \
		-f ${FEAT} \
		-x ${ALIGNTHR} \
		-1 ${WEIGHTG} \
		-2 ${WEIGHTP} \
		-3 ${WEIGHTN} \
		-N -L -v \
		-l ${SEARCH} ${EXTRAOPT} > /dev/null


#-------------------------------------------------------------------------
# call Moses/Giza++ to run word alignment and extract lexical probabilities
#-------------------------------------------------------------------------

moses-sophie: moses-sophie/model/aligned.${MOSES_SYM}
moses-eco: moses-eco/model/aligned.${MOSES_SYM}
moses-dvd: moses-dvd/model/aligned.${MOSES_SYM}

${SOPHIE}.${SRC}: ${SMULTRON}/${SOPHIE}.xml
	../bin/sta2moses $<

moses-sophie/model/aligned.%: ${SOPHIE}.${SRC} # ${SOPHIE}.${TRG}
	${MOSESTRAINING}/train-factored-phrase-model.perl \
	    -corpus ${SOPHIE} \
	    -root-dir moses-sophie \
	    -f ${SRC} --e ${TRG} \
	    -alignment `echo '$@'|sed 's/^.*\.//'` \
	    --parallel \
	    --last-step 4

${ECO}.${SRC}: ${SMULTRON}/${ECO}.xml
	../bin/sta2moses $<

moses-eco/model/aligned.%: ${ECO}.${SRC} # ${ECO}.${TRG}
	${MOSESTRAINING}/train-factored-phrase-model.perl \
	    -corpus ${ECO} \
	    -root-dir moses-eco \
	    -f ${SRC} --e ${TRG} \
	    -alignment `echo '$@'|sed 's/^.*\.//'` \
	    --parallel \
	    --last-step 4


${DVDMAN}.${SRC}: ${SMULTRON}/${DVDMAN}.xml
	../bin/sta2moses $<

moses-dvd/model/aligned.%: ${DVDMAN}.${SRC}
	${MOSESTRAINING}/train-factored-phrase-model.perl \
	    -corpus ${DVDMAN} \
	    -root-dir moses-dvd \
	    -f ${SRC} --e ${TRG} \
	    -alignment `echo '$@'|sed 's/^.*\.//'` \
	    --parallel \
	    --last-step 4




#-------------------------------------------------------------------------
# run alignment with different feature sets:
# 
#  make test-no-moses1 ..... without MOSES/GIZA++ features (no Dice)
#  make test-no-moses2 ..... without MOSES/GIZA++ features including Dice scores
#  make test-cooc .......... Dice scores only

NO_MOSES_FEAT1 = catpos:edge:parent_catpos:srcparent_catpos:trgparent_catpos:children_catpos:sister_catpos:treelevelsim:treespansim

NO_MOSES_FEAT2 = dicecat=cat.cooc:dicepos=pos.cooc:diceword=word.cooc:dicewordpcat=wordpcat.cooc:dicesuffixpcat=suffixpcat.cooc:dicesuffixpos=suffixpos.cooc:dicesuffix=suffix.cooc:treelevelsim:treespansim:parent_dicecat=cat.cooc:srcparent_dicecat=cat.cooc:trgparent_dicecat=cat.cooc:diceother=other.cooc:catpos:edge:parent_catpos:srcparent_catpos:trgparent_catpos:children_catpos:sister_catpos:dicepospcat=pospcat.cooc

COOC_FEAT = dicecat=cat.cooc:dicepos=pos.cooc:diceword=word.cooc:dicewordpcat=wordpcat.cooc:dicesuffixpcat=suffixpcat.cooc:dicesuffixpos=suffixpos.cooc:dicesuffix=suffix.cooc:parent_dicecat=cat.cooc:srcparent_dicecat=cat.cooc:trgparent_dicecat=cat.cooc:diceother=other.cooc:dicepospcat=pospcat.cooc


test-no-moses1:
	make FEAT=${NO_MOSES_FEAT1} sophie

test-no-moses2: cooc-freq
	make FEAT=${NO_MOSES_FEAT2} sophie

# compute various co-occurrence frequencies (for Dice scores)

cooc-freq: cat.cooc pos.cooc word.cooc wordpcat.cooc pospcat.cooc \
		suffixpcat.cooc suffixpos.cooc suffix.cooc other.cooc

test-dice: cooc-freq
	make FEAT=${COOC_FEAT} sophie




#-------------------------------------------------------------------------
# all kind of different co-occurrence frequencies
# (for different types of features)

pos.cooc:
	../bin/coocfreq -a ${TRAINCORPUS}.xml -A sta \
			-x pos -y pos \
			-f pos.src -e pos.trg -c $@

pospcat.cooc:
	../bin/coocfreq -a ${TRAINCORPUS}.xml -A sta \
			-x pos:parent_cat -y pos:parent_cat \
			-f pospcat.src -e pospcat.trg -c $@


cat.cooc:
	../bin/coocfreq -a ${TRAINCORPUS}.xml -A sta \
			-x cat -y cat \
			-f cat.src -e cat.trg -c $@

other.cooc:
	../bin/coocfreq -a ${TRAINCORPUS}.xml -A sta \
			-x edge:cat:pos -y edge:morph:cat:pos \
			-f other.src -e other.trg -c $@

word.cooc:
	../bin/coocfreq -a ${TRAINCORPUS}.xml -A sta \
			-x word -y word \
			-f word.src -e word.trg -c $@

wordpcat.cooc:
	../bin/coocfreq -a ${TRAINCORPUS}.xml -A sta \
			-x word:parent_cat -y word:parent_cat \
			-f wordpcat.src -e wordpcat.trg -c $@

suffixpcat.cooc:
	../bin/coocfreq -a ${TRAINCORPUS}.xml -A sta \
			-x suffix=3:parent_cat -y suffix=3:parent_cat \
			-f suffixpcat.src -e suffixpcat.trg -c $@

suffixpos.cooc:
	../bin/coocfreq -a ${TRAINCORPUS}.xml -A sta \
			-x suffix=3:parent_cat -y suffix=3:pos \
			-f suffixpos.src -e suffixpos.trg -c $@

suffix.cooc:
	../bin/coocfreq -a ${TRAINCORPUS}.xml -A sta \
			-x suffix=4 -y suffix=4 \
			-f suffix.src -e suffix.trg -c $@



###########################################################################
###########################################################################
###########################################################################
#
# below: a lot of other (undocumented) tests and tree aligner calls .....
# 














#
# different settings tested for the TLT paper (and for LREC2010)
#



NEWTEST = 'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink:moses.catpos:giza.catpos:catpos:treelevelsim.catpos:maxinside.catpos' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink:catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:moses.catpos:giza.catpos:children_catpos:children_catpos.catpos:treelevelsim.catpos:maxinside.catpos' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink:catpos:moses.catpos:giza.catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:children_catpos:children_catpos.catpos:parent_giza:sister_giza.catpos:sister_moses.catpos:children_giza.catpos:treelevelsim.catpos:maxinside.catpos'



newtest: newtest1 newtest2

newtest1:
	for f in ${NEWTEST}; do \
		make SEARCH=greedy FEAT=$$f sophie >> $@.greedy; \
	done
	for f in ${NEWTEST}; do \
		make SEARCH=wellformed FEAT=$$f sophie >> $@.wellformed; \
	done
	for f in ${NEWTEST}; do \
		make SEARCH=assign FEAT=$$f sophie >> $@.assign; \
	done
	for f in ${NEWTEST}; do \
		make EXTRAOPT='-R 3' SEARCH=wellformed FEAT=$$f sophie >> $@.searn; \
	done



newtest2:
	for f in ${NEWTEST}; do \
		make EXTRAOPT='-C -U' SEARCH=greedy FEAT=$$f sophie >> $@.greedy; \
	done
	for f in ${NEWTEST}; do \
		make EXTRAOPT='-C -U' SEARCH=wellformed FEAT=$$f sophie >> $@.wellformed; \
	done
	for f in ${NEWTEST}; do \
		make EXTRAOPT='-C -U' SEARCH=assign FEAT=$$f sophie >> $@.assign; \
	done
	for f in ${NEWTEST}; do \
		make EXTRAOPT='-C -U -R 3' SEARCH=wellformed FEAT=$$f sophie >> $@.searn; \
	done


newtest3:
	for f in ${NEWTEST}; do \
		make EXTRAOPT='-C -U' SEARCH=wellformed FEAT=$$f \
			WEIGHTG=10 WEIGHTP=8 WEIGHTN=1 \
			sophie >> $@.wellformed; \
	done



#	for ((t=5; t <= 100 ; t+=5)); do \
#
DATASIZES=1 2 4 8 16 32 64 128 256
# DATASIZEFEAT='maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS'
# DATASIZEFEAT='maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink:catpos:moses.catpos:giza.catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:children_catpos:children_catpos.catpos:parent_giza:sister_giza.catpos:sister_moses.catpos:children_giza.catpos:treelevelsim.catpos:maxinside.catpos'
# DATASIZEFEAT='treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:children_catpos:children_catpos.catpos:treelevelsim.catpos'
DATASIZEFEAT='maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink:parent_giza:children_giza:srcparent_giza:trgparent_giza:srcparent_giza*trgparent_giza:sister_giza:srcsister_giza:trgsister_giza:sister_giza:srcsister_giza*trgsister_giza:srcchildren_giza:trgchildren_giza:children_giza:srcchildren_giza*trgchildren_giza'


datasize4:
	for t in ${DATASIZES}; do \
	   make FEAT=${DATASIZEFEAT} \
		EXTRAOPT='-C -U' SEARCH=wellformed \
		STARTEVAL=337 \
		NR_TRAIN=$$t sophie >> $@; \
	done



sophie.test: moses-sophie
	${TREEALIGN} \
		-a ${SMULTRON}/${SOPHIE}.xml \
		-M $< \
		-f ${FEAT} \
		-n 0 \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-1 ${WEIGHTG} \
		-2 ${WEIGHTP} \
		-3 ${WEIGHTN} \
		-N -L -v \
		-l ${SEARCH} ${EXTRAOPT} > $@.alg
	${ALIGNEVAL} -b ${STARTEVAL} -e ${ENDEVAL} \
		${SMULTRON}/${SOPHIE}.xml $@.alg



# train model on NR_TRAIN sentences (and don't align anything)

sophie.megam: moses-sophie
	./train.pl \
		-a ${SMULTRON}/${SOPHIE}.xml \
		-m $@ \
		-M $< \
		-N -L \
		-k \
		-f ${FEAT} \
		-n ${NR_TRAIN} \
		-l ${SEARCH} ${EXTRAOPT}


sophie.align: sophie.megam
	./align.pl \
		-a ${SMULTRON}/${SOPHIE}.xml \
		-m $< \
		-M moses-sophie \
		-N -L \
		-n ${NR_TRAIN} \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-l ${SEARCH} ${EXTRAOPT} > $@.alg
	../bin/eval_sta ${SMULTRON}/${SOPHIE}.xml $@.alg






sophie.wordalign: sophie.wordalign-inter words-grow.clue \
		moses-sophie/model/aligned.grow-diag
	./align.pl \
		-c clue \
		-a sophie.wordalign-inter \
		-u \
		-m words-grow.clue \
		-M moses-sophie \
		-y moses-sophie/model/aligned.grow-diag \
		-L \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-l threshold ${EXTRAOPT} > $@
	../bin/eval_sta ${SMULTRON}/${SOPHIE}.xml $@




words-grow.clue:
	echo 'moseslink 0.4' > $@
	echo 'moseslink' > $@.feat

words-intersect.clue:
	echo 'moseslink 0.8' > $@
	echo 'moseslink' > $@.feat

sophie.wordalign-inter: words-intersect.clue
	./align.pl \
		-c clue \
		-a ${SMULTRON}/${SOPHIE}.xml \
		-m $< \
		-M moses-all \
		-y moses-all/model/aligned.intersect \
		-L \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-l threshold ${EXTRAOPT} > $@
	../bin/eval_sta ${SMULTRON}/${SOPHIE}.xml $@


sophie.wordalign-grow: moses-sophie/model/aligned.grow-diag-final-and \
			words-grow.clue
	./align.pl \
		-c clue \
		-a ${SMULTRON}/${SOPHIE}.xml \
		-m words-grow.clue \
		-M moses-sophie \
		-y $< \
		-L \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-l threshold ${EXTRAOPT} > $@
	../bin/eval_sta ${SMULTRON}/${SOPHIE}.xml $@









TESTFEAT = 'inside4:outside4' \
	'inside2:outside2' \
	'inside4:outside4:inside4*outside4:inside4+outside4' \
	'inside2:outside2:inside2*outside2:inside2+outside2' \
	'insideST2:insideTS2:outsideST2:outsideTS2' \
	'avgmaxinside*avgmaxoutside' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside' \
	'avgmaxinside:avgmaxoutside:avgmaxinside*avgmaxoutside:avgmaxinside+avgmaxoutside' \
	'avgmaxinsideST:avgmaxinsideTS:avgmaxoutsideST:avgmaxoutsideTS' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS' \
	'treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio' \
	'moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza' \
	'catpos' \
	'catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:children_catpos:children_catpos.catpos' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:catpos:giza.catpos:moses.catpos' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:children_catpos:children_catpos.catpos' \
	'nrleafsratio:inside4:outside4:inside4*outside4:parent_inside4:insideST2:insideTS2:maxinsideST:maxinsideTS:inside4*parent_inside4:treelevelsim:treelevelsim*inside4:treespansim:treespansim*treelevelsim:giza:parent_giza:moses:moseslink' \
	'nrleafsratio:inside4:outside4:inside4*outside4:parent_inside4:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:inside4*parent_inside4:treelevelsim:treelevelsim*inside4:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos' \
	'nrleafsratio:insideST2:insideTS2:outsideST2:outsideTS2:parent_inside4:parent_catpos:catpos.parent_catpos:maxinsideST:maxinsideTS:inside4*parent_inside4:treelevelsim:treelevelsim*inside4:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos' \
	'nrleafsratio:maxinside:maxoutside:maxinside*maxoutside4:parent_maxinside:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:maxinside*parent_maxinside:treelevelsim:treelevelsim*maxinside:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos:avgmaxinside:avgmaxoutside:avgmaxinside*avgmaxoutside:avgmaxinside.catpos'






test_new:
	for f in ${TESTFEAT}; do \
		make FEAT=$$f sophie >> $@; \
	done
	echo "now with linked parents" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-P' sophie >> $@; \
	done
	echo "now with linked children" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-C' sophie >> $@; \
	done
	echo "now with linked subtree nodes" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-U' sophie >> $@; \
	done
	echo "now with linked children & subtree nodes" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-C -U' sophie >> $@; \
	done
	echo "now with linked children & subtree nodes & SEARN=2" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-C -U -R 2' sophie >> $@; \
	done









moses-sophie_deen: moses-sophie_deen/model/aligned.${MOSES_SYM}
moses-all: moses-all/model/aligned.${MOSES_SYM}

${SOPHIE_DEEN}.${SRC}: ${SMULTRON}/${SOPHIE_DEEN}.xml
	../bin/sta2moses $<

moses-sophie_deen/model/aligned.%: ${SOPHIE_DEEN}.${SRC} # ${SOPHIE}.${TRG}
	${MOSESTRAINING}/train-factored-phrase-model.perl \
	    -corpus ${SOPHIE_DEEN} \
	    -root-dir moses-sophie_deen \
	    -f ${SRC} --e ${TRG} \
	    -alignment `echo '$@'|sed 's/^.*\.//'` \
	    --parallel \
	    --last-step 4




UPLUG = ${HOME}/projects/uplug

ep.sv:  ${HOME}/projects/OPUS/corpus/Europarl3/xml/en-sv.ces.gz
	zcat $< |\
	${UPLUG}/tools/opus2moses.pl -l -1 -p ep.ensv.sentids \
			-d ${HOME}/projects/OPUS/corpus/Europarl3 \
			-e ep.en -f ep.sv


all.${SRC}: ${SOPHIE}.src ep.sv ${ECO}.src
	cat $^ > $@

all.${TRG}:
	cat ${SOPHIE}.trg ep.en ${ECO}.trg > $@



moses-all/model/aligned.%: all.${SRC} all.${TRG}
	${MOSESTRAINING}/train-factored-phrase-model.perl \
	    -corpus all \
	    -root-dir moses-all \
	    -f ${SRC} --e ${TRG} \
	    -alignment `echo '$@'|sed 's/^.*\.//'` \
	    --parallel \
	    --last-step 4








