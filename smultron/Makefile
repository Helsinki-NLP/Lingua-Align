
SMULTRON=${HOME}/projects/SMULTRON
# SMULTRON=.
SOPHIE=Alignments_SMULTRON_Sophies_World_SV_EN
SOPHIE_DEEN=Alignments_SMULTRON_Sophies_World_DE_EN
ECO=Alignments_SMULTRON_Economy_Texts_SV_EN


#-------------------------------------------------------------------------
# nr sentences used for training and testing
# STARTEVAL: gives first sentID that will be aligned (for evaluation!)
# ENDEVAL: gives last sentID that will be aligned (for evaluation!)

NR_TRAIN = 100
STARTEVAL = 104

# NR_TEST = 100
# ENDEVAL = 209

# big value --> use all remaining sentences for testing!

NR_TEST = 10000
ENDEVAL = 10000

# for small tests with only 20 sentences:
# (start and end IDs are not correct --> check that!)

# NR_TRAIN = 20
# NR_TEST = 20
# STARTEVAL = 22
# ENDEVAL = 42



CLASSIFIER = megam

SEARCH = wellformed
# SEARCH = greedy
# SEARCH = assign
#
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

ALIGNTHR = 0.1
# EXTRAOPT = -C -U

MOSES = ${SMTHOME}/moses-irstlm/moses-cmd/src/moses
MOSESTRAINING = ${SCRIPTS_ROOTDIR}/training

SRC=src
TRG=trg

PACO            = ${HOME}/projects/PACO-MT
TREEALIGNERHOME = ${PACO}/tools/Lingua-Align-dev
# TREEALIGNERHOME = ..
# TREEALIGN       = ${TREEALIGNERHOME}/bin/treealign -c megam.osx
TREEALIGN       = ${TREEALIGNERHOME}/bin/treealign

STA2MOSES       = ${TREEALIGNERHOME}/bin/sta2moses
ALIGNEVAL       = ${TREEALIGNERHOME}/bin/eval_sta


# FEAT = 'nrleafsratio:inside2:outside2:inside2*outside2:parent_inside2:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:inside2*parent_inside2:treelevelsim:treelevelsim*inside2:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos'

FEAT = 'nrleafsratio:inside4:outside4:inside4*outside4:parent_inside4:parent_catpos:catpos.parent_catpos:insideST4:insideTS4:maxinsideST:maxinsideTS:inside4*parent_inside4:treelevelsim:treelevelsim*inside4:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos'




NEWTEST = 'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink:moses.catpos:giza.catpos:catpos:treelevelsim.catpos:maxinside.catpos' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink:catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:moses.catpos:giza.catpos:children_catpos:children_catpos.catpos:treelevelsim.catpos:maxinside.catpos' \
	'maxinsideST:maxinsideTS:maxoutsideST:maxoutsideTS:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:moseslink:catpos:moses.catpos:giza.catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:children_catpos:children_catpos.catpos:parent_giza:sister_giza.catpos:sister_moses.catpos:children_giza.catpos:treelevelsim.catpos:maxinside.catpos'

all: sophie

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



WEIGHTG=3
WEIGHTP=1
WEIGHTN=1

# train model on NR_TRAIN sentences and align the following NR_TEST sentences

sophie: moses-sophie
	${TREEALIGN} \
		-a ${SMULTRON}/${SOPHIE}.xml \
		-M $< \
		-f ${FEAT} \
		-n ${NR_TRAIN} \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-1 ${WEIGHTG} \
		-2 ${WEIGHTP} \
		-3 ${WEIGHTN} \
		-N -L -v \
		-l ${SEARCH} ${EXTRAOPT} > $@.alg
	${ALIGNEVAL} -b ${STARTEVAL} -e ${ENDEVAL} \
		${SMULTRON}/${SOPHIE}.xml $@.alg


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









MOSES_SYM=intersect
# MOSES_SYM=grow-diag-final-and

moses-sophie: moses-sophie/model/aligned.${MOSES_SYM}
moses-sophie_deen: moses-sophie_deen/model/aligned.${MOSES_SYM}
moses-eco: moses-eco/model/aligned.${MOSES_SYM}
moses-all: moses-all/model/aligned.${MOSES_SYM}

${SOPHIE}.${SRC}: ${SMULTRON}/${SOPHIE}.xml
	../bin/sta2moses $<

${SOPHIE_DEEN}.${SRC}: ${SMULTRON}/${SOPHIE_DEEN}.xml
	../bin/sta2moses $<

moses-sophie/model/aligned.%: ${SOPHIE}.${SRC} # ${SOPHIE}.${TRG}
	${MOSESTRAINING}/train-factored-phrase-model.perl \
	    -corpus ${SOPHIE} \
	    -root-dir moses-sophie \
	    -f ${SRC} --e ${TRG} \
	    -alignment `echo '$@'|sed 's/^.*\.//'` \
	    --parallel \
	    --last-step 4


moses-sophie_deen/model/aligned.%: ${SOPHIE_DEEN}.${SRC} # ${SOPHIE}.${TRG}
	${MOSESTRAINING}/train-factored-phrase-model.perl \
	    -corpus ${SOPHIE_DEEN} \
	    -root-dir moses-sophie_deen \
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


