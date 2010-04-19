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

# TRAINCORPUS = nl-en_125
TRAINCORPUS = nl-en-weak_125
NR_TRAIN    = 100
NR_TEST     = 25
CLASSIFIER  = megam

# link search strategy (greedy|wellformed|threshold)
# alignment score threshold

SEARCH      = wellformed
ALIGNTHR    = 0.15

# extra options to be passed to the tree aligner (e.g. link dependencies -C -U)
EXTRAOPT    = -C -U


#-------------------------------------------------------------------------
# really important: the features used in the model!
#-------------------------------------------------------------------------


FEAT = 'nrleafsratio:inside2:outside2:inside2*outside2:parent_inside2:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:inside2*parent_inside2:treelevelsim:treelevelsim*inside2:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos'

run: clean all
all: treealign.megam


#		-g gideon_100.src-trg.A3 \
#		-G gideon_100.trg-src.A3 \
#		-y gideon_100.aligned.intersect \

#		-X '../bin/megam -maxi 10 -bnsfs 50' \

# megam arguments:
#   -bnfsf int ...... keep only <int> features by the BNS selection criteria
#   -minfc int ...... remove features with freq <= <int>
#   -lambda float ... precision of Gaussian (default=1)
#   -mean file ...... file with Gaussian prior mean for all features
#   -tune ........... tune lambda (requires development data!!)
#   -nobias ......... do not use a BIAS feature (?)
#

treealign.megam:
	../bin/treealign \
		-c ${CLASSIFIER} \
		-a ${TRAINCORPUS}.xml \
		-m $@ \
		-X '../bin/megam -maxi 50' \
		-b bottom-up \
		-I moses/model/aligned.ids \
		-g moses/giza.src-trg/src-trg.A3.final.gz \
		-G moses/giza.trg-src/trg-src.A3.final.gz \
		-y moses/model/aligned.intersect \
		-f ${FEAT} \
		-1 10 -2 3 -3 1 -4 1 \
		-n ${NR_TRAIN} \
		-e ${NR_TEST} \
		-v \
		-x ${ALIGNTHR} \
		-l ${SEARCH} ${EXTRAOPT} > ${TRAINCORPUS}.${NR_TRAIN}.align
	../bin/eval_sta ${TRAINCORPUS}.xml ${TRAINCORPUS}.${NR_TRAIN}.align

TESTFEAT=gizae2f:moses

test:
	../bin/treealign \
		-c ${CLASSIFIER} \
		-a ${TRAINCORPUS}.xml \
		-m test.megam \
		-I moses/model/aligned.ids \
		-g moses/giza.src-trg/src-trg.A3.final.gz \
		-G moses/giza.trg-src/trg-src.A3.final.gz \
		-y moses/model/aligned.intersect \
		-f ${TESTFEAT} \
		-n 10 \
		-e 10 \
		-v 3 \
		-x ${ALIGNTHR} \
		-l ${SEARCH} ${EXTRAOPT} > test.align
	../bin/eval_sta ${TRAINCORPUS}.xml test.align



clean:
	rm -f ${TRAINCORPUS}.${NR_TRAIN}.align
	rm -f treealign.megam
