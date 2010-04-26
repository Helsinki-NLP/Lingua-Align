#---------------------------------------------------------------------------
# j.tiedemann@rug.nl			18 June 2009
#
# Makefile for testing the tree-aligner with some Europarl data
#
#
# make run ...... run training and testing using the parameters below
# make test ..... run a quick test with much less training examples
#                 and simple features (for fast feature extraction)
#---------------------------------------------------------------------------



#-------------------------------------------------------------------------
# training corpus (STA format)
#
# nl-en_125 ........ 125 tree pairs from Europarl (fuzzy & good links)
# nl-en-weak_125 ... the same 125 trees but some links are marked as 'weak'
#-------------------------------------------------------------------------

# TRAINCORPUS = nl-en_125
TRAINCORPUS = nl-en-weak_125
NR_TRAIN    = 90
NR_DEV      = 10
NR_TEST     = 25
CLASSIFIER  = megam
MEGAMARGS   = -maxi 100 -tune

#-------------------------------------------------------------------------
# training & alignment options
#
# - basic alignment algorithm: 
#      two-step classify+inference (=inference) OR
#      bottom-up classify+immediate-linking
# - link search strategy (greedy|wellformed|threshold...)
# - alignment score threshold
#-------------------------------------------------------------------------

# ALIGN       = bottom-up
ALIGN       = inference
# SEARCH      = wellformed
SEARCH	    = Src2TrgWellFormed
# ALIGNTHR    = 0.15
ALIGNTHR    = 0

# extra options to be passed to the tree aligner (e.g. link dependencies -C -U)
# EXTRAOPT    = -C -U


#-------------------------------------------------------------------------
# really important: the features used in the model!
#-------------------------------------------------------------------------


FEAT = 'nrleafsratio:inside2:outside2:inside2*outside2:parent_inside2:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:inside2*parent_inside2:treelevelsim:treelevelsim*inside2:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos'


# run a new experiment (remove old alignment first)

run: clean all


# run a fast test alignment

TESTOPT = 	NR_TRAIN=10 NR_DEV=0 NR_TEST=10 \
		FEAT=gizae2f:moses:catpos MEGAMARGS='-maxi 20'

test: clean
	make ${TESTOPT} all


all: treealign.megam



# megam arguments:
#   -bnfsf int ...... keep only <int> features by the BNS selection criteria
#   -minfc int ...... remove features with freq <= <int>
#   -lambda float ... precision of Gaussian (default=1)
#   -mean file ...... file with Gaussian prior mean for all features
#   -tune ........... tune lambda (requires development data!!)
#   -nobias ......... do not use a BIAS feature (?)
#

# additional treealign arguments:
#   -r 10  .... random negative training examples (10 x more than positive)
#   -B ........ negative neighbors only in training

treealign.megam:
	../bin/treealign \
		-c ${CLASSIFIER} \
		-a ${TRAINCORPUS}.xml \
		-m $@ \
		-o '${MEGAMARGS}' \
		-b ${ALIGN} \
		-I moses/model/aligned.ids \
		-g moses/giza.src-trg/src-trg.A3.final.gz \
		-G moses/giza.trg-src/trg-src.A3.final.gz \
		-y moses/model/aligned.intersect \
		-f ${FEAT} \
		-1 3 -2 1 -3 1 -4 1 \
		-n ${NR_TRAIN} \
		-V ${NR_DEV} \
		-e ${NR_TEST} \
		-v \
		-x ${ALIGNTHR} \
		-l ${SEARCH} ${EXTRAOPT} \
			> ${TRAINCORPUS}.${NR_TRAIN}.${NR_DEV}.align
	../bin/eval_sta ${TRAINCORPUS}.xml \
			${TRAINCORPUS}.${NR_TRAIN}.${NR_DEV}.align



clean:
	rm -f ${TRAINCORPUS}.${NR_TRAIN}.align
	rm -f treealign.megam
