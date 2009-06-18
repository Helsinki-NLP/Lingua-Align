#---------------------------------------------------------------------------
# j.tiedemann@rug.nl			18 June 2009
#
# Makefile for testing the tree-aligner with some Europarl data
#
#
# make test .......... train a model on 80 sentences and eval on 20
# make run ........... train a model and align the given test corpus
#
#---------------------------------------------------------------------------


# training corpus (STA format)

TRAINCORPUS = gideon_100
NR_TRAIN    = 80
NR_TEST     = 20
CLASSIFIER  = megam

# link search strategy (greedy|wellformed|threshold)
# alignment score threshold

SEARCH      = wellformed
ALIGNTHR    = 0

# extra options to be passed to the tree aligner (e.g. link dependencies -C -U)
# EXTRAOPT    = -C -U

# name of the test corpus

CORPUS     = ep-00-01-17

# input files and their formats

SENTALIGN  = ${CORPUS}.ces.gz

SRCTREES   = ${CORPUS}.stanford.gz
SRCFORMAT  = penn
TRGTREES   = ${CORPUS}.data.dz
TRGFORMAT  = alpino

SRCTIGER   = ${CORPUS}.en.tiger
TRGTIGER   = ${CORPUS}.nl.tiger



#-------------------------------------------------------------------------
# really important: the features used in the model!
#-------------------------------------------------------------------------


FEAT = 'nrleafsratio:inside2:outside2:inside2*outside2:parent_inside2:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:inside2*parent_inside2:treelevelsim:treelevelsim*inside2:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos'





run: train align

test: train_test.megam
	rm -f $<

train_test.megam:
	../bin/treealign \
		-c ${CLASSIFIER} \
		-a ${TRAINCORPUS}.xml \
		-g gideon_100.src-trg.A3 \
		-G gideon_100.trg-src.A3 \
		-y gideon_100.aligned.intersect \
		-m $@ \
		-f ${FEAT} \
		-n ${NR_TRAIN} \
		-e ${NR_TEST} \
		-N -v \
		-x ${ALIGNTHR} \
		-l ${SEARCH} ${EXTRAOPT} > ${TRAINCORPUS}.${NR_TRAIN}.align
	../bin/eval_sta ${TRAINCORPUS}.xml ${TRAINCORPUS}.${NR_TRAIN}.align



train: treealign.megam

treealign.megam: 
	../bin/treealign \
		-c ${CLASSIFIER} \
		-a ${TRAINCORPUS}.xml \
		-g gideon_100.src-trg.A3 \
		-G gideon_100.trg-src.A3 \
		-y gideon_100.aligned.intersect \
		-m $@ \
		-f ${FEAT} \
		-n 100000 \
		-e 0 -v -N \
		-x ${ALIGNTHR} \
		-l ${SEARCH} ${EXTRAOPT}




# two-step alignment tree alignment
#
# 1) terminal nodes (add word alignment - see below ${CORPUS}.wordalign)
# 2) non-terminal nodes (result in ${CORPUS}.align.gz)

align: ${CORPUS}.align.gz

${CORPUS}.align.gz: ${SRCTIGER} ${TRGTIGER} treealign.megam ${CORPUS}.wordalign
	../bin/treealign \
	${TREEALIGN} \
		-a ${CORPUS}.wordalign -A sta \
		-s ${SRCTIGER} -S tiger \
		-t ${TRGTIGER} -T tiger \
		-N -v -u \
		-m treealign.megam \
		-I ep.sentids \
		-x ${ALIGNTHR} \
		-l ${SEARCH} ${EXTRAOPT} |\
	gzip -c > $@
	rm -f ${CORPUS}.wordalign
	rm -f ${CORPUS}.wordalign-intersect
	gzip -f ${CORPUS}.*.tiger


# align terminal nodes using the moseslink feature 
#
# 1a) add intersection links as 'good' links (hard-coded score = 0.8)
# 1b) add links from grow-diag as 'fuzzy' links (hard-coded score = 0.4)

align_words: ${CORPUS}.wordalign

${CORPUS}.wordalign: ${SRCTIGER} ${TRGTIGER} ${CORPUS}.wordalign-intersect
	../bin/treealign \
		-c clue \
		-a ${CORPUS}.wordalign-intersect \
		-A sta \
		-s ${SRCTIGER} -S tiger \
		-t ${TRGTIGER} -T tiger \
		-x 0.2 \
		-u -v -L \
		-y moses-ep/model/aligned.grow-diag \
		-m words-grow.clue \
		-I ep.sentids \
		-l threshold ${EXTRAOPT} > $@

${CORPUS}.wordalign-intersect: ${SRCTIGER} ${TRGTIGER} 
	../bin/treealign \
		-c clue \
		-a ${SENTALIGN} -A opus \
		-s ${SRCTIGER} -S tiger \
		-t ${TRGTIGER} -T tiger \
		-x 0.2 -v -L \
		-y moses-ep/model/aligned.intersect \
		-m words-intersect.clue \
		-I ep.sentids \
		-l threshold ${EXTRAOPT} > $@


${SRCTIGER}: ${SRCTREES}
	../bin/${SRCFORMAT}2tiger $< $@

${TRGTIGER}: ${TRGTREES}
	../bin/${TRGFORMAT}2tiger $< $@



