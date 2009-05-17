

NR_TRAIN = 100
NR_TEST = 100
MODEL = megam

# SEARCH = wellformed
SEARCH = greedy
ALIGNTHR = 0.15
EXTRAOPT = -C -S

SMULTRON=${HOME}/projects/SMULTRON
SOPHIE=Alignments_SMULTRON_Sophies_World_SV_EN
ECO=Alignments_SMULTRON_Economy_Texts_SV_EN

TRAIN=${SOPHIE}

MOSES = ${SMTHOME}/moses-irstlm/moses-cmd/src/moses
MOSESTRAINING = ${SCRIPTS_ROOTDIR}/training

SRC=src
TRG=trg



# FEAT = 'nrleafsratio:inside2:outside2:inside2*outside2:parent_inside2:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:maxinside:maxoutside:parent_maxinside:inside2*parent_inside2:treelevelsim:treelevelsim*inside2:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos'


FEAT = 'nrleafsratio:inside2:outside2:inside2*outside2:parent_inside2:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:inside2*parent_inside2:treelevelsim:treelevelsim*inside2:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos'

# FEAT = 'nrleafsratio:maxinside:maxoutside:maxinside*maxoutside2:parent_maxinside:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:maxinside*parent_maxinside:treelevelsim:treelevelsim*maxinside:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos:avgmaxinside:avgmaxoutside:avgmaxinside*avgmaxoutside:avgmaxinside.catpos'


all: sophie



sophie: moses-sophie
	./train_align.pl \
		-m ${MODEL} \
		-c ${SMULTRON}/${SOPHIE}.xml \
		-M $< \
		-f ${FEAT} \
		-t ${NR_TRAIN} \
		-a ${NR_TEST} \
		-x ${ALIGNTHR} \
		-s ${SEARCH} ${EXTRAOPT} > $@.alg
	../bin/eval_sta ${SMULTRON}/${SOPHIE}.xml $@.alg

eco: moses-eco
	./train_align.pl \
		-m ${MODEL} \
		-c ${SMULTRON}/${ECO}.xml \
		-M $< \
		-f ${FEAT} \
		-t ${NR_TRAIN} \
		-a ${NR_TEST} \
		-x ${ALIGNTHR} \
		-s ${SEARCH} ${EXTRAOPT} > $@.alg
	../bin/eval_sta ${SMULTRON}/${ECO}.xml $@.alg


sophie_eco: moses-sophie moses-eco
	./train.pl \
		-m ${MODEL} \
		-c ${SMULTRON}/${SOPHIE}.xml \
		-M moses-sophie \
		-f ${FEAT} \
		-t ${NR_TRAIN} \
		-x ${ALIGNTHR} \
		-o sophie.megam \
		${EXTRAOPT} > $@.alg
	./align.pl \
		-m ${MODEL} \
		-c ${SMULTRON}/${ECO}.xml \
		-M moses-eco \
		-f ${FEAT} \
		-a ${NR_TEST} \
		-x ${ALIGNTHR} \
		-o sophie.megam \
		-s ${SEARCH} ${EXTRAOPT} > $@.alg
	../bin/eval_sta ${SMULTRON}/${ECO}.xml $@.alg


eco_sophie: moses-sophie moses-eco
	./train.pl \
		-m ${MODEL} \
		-c $${SMULTRON}/{ECO}.xml \
		-M moses-eco \
		-f ${FEAT} \
		-t ${NR_TRAIN} \
		-x ${ALIGNTHR} \
		-o eco.megam \
		${EXTRAOPT} > $@.alg
	./align.pl \
		-m ${MODEL} \
		-c ${SMULTRON}/${SOPHIE}.xml \
		-M moses-sophie \
		-f ${FEAT} \
		-a ${NR_TEST} \
		-x ${ALIGNTHR} \
		-o eco.megam \
		-s ${SEARCH} ${EXTRAOPT} > $@.alg
	../bin/eval_sta ${SMULTRON}/${SOPHIE}.xml $@.alg



MOSES_SYM=intersect
# MOSES_SYM=grow-diag-final-and

moses-sophie: moses-sophie/model/aligned.${MOSES_SYM}
moses-eco: moses-eco/model/aligned.${MOSES_SYM}
moses-all: moses-all/model/aligned.${MOSES_SYM}

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


all.${SRC}:
	cat ${SOPHIE}.src ${ECO}.src ../europarl/ep.src > $@

all.${TRG}:
	cat ${SOPHIE}.trg ${ECO}.trg ../europarl/ep.trg > $@



moses-all/model/aligned.%: all.${SRC} all.${TRG}
	${MOSESTRAINING}/train-factored-phrase-model.perl \
	    -corpus all \
	    -root-dir moses-all \
	    -f ${SRC} --e ${TRG} \
	    -alignment `echo '$@'|sed 's/^.*\.//'` \
	    --parallel \
	    --last-step 4







STRATEGIES = greedy inter src2trg trg2src 

TREE_FEAT  = treespansim treelevelsim nrleafsratio
LABEL_FEAT = catpos
LEX_FEAT   = insideST1 insideTS1 insideST2 insideTS2 inside1 inside2 \
		maxinsideST maxinsideTS maxinside \
		outsideST1 outsideTS1 outsideST2 outsideTS2 outside1 outside2 \
		maxoutsideST maxoutsideTS maxoutside
ALIGN_FEAT = moses gizae2f gizaf2e giza

ALL_FEAT = ${TREE_FEAT} ${LABEL_FEAT} ${LEX_FEAT} ${ALIGN_FEAT}

TESTFEAT = 	'inside2*outside2' \
	'inside2:outside2' \
	'inside2:outside2:inside2*outside2:inside2+outside2' \
	'avgmaxinside*avgmaxoutside' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside' \
	'avgmaxinside:avgmaxoutside:avgmaxinside*avgmaxoutside:avgmaxinside+avgmaxoutside' \
	'treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio' \
	'moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza' \
	'catpos' \
	'catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:children_catpos:children_catpos.catpos' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:catpos:giza.catpos:moses.catpos' \
	'maxinside:maxoutside:maxinside*maxoutside:maxinside+maxoutside:treespansim:treelevelsim:nrleafsratio:treespansim*treelevelsim:treespansim:nrleafsratio:treelevelsim:nrleafsratio:moses:gizae2f:gizaf2e:giza:moses*gizae2f:moses*gizaf2e:moses*giza:catpos:parent_catpos:parent_catpos.catpos:sister_catpos:sister_catpos.catpos:children_catpos:children_catpos.catpos' \
	'nrleafsratio:inside2:outside2:inside2*outside2:parent_inside2:insideST2:insideTS2:maxinsideST:maxinsideTS:inside2*parent_inside2:treelevelsim:treelevelsim*inside2:treespansim:treespansim*treelevelsim:giza:parent_giza:moses:moseslink' \
	'nrleafsratio:inside2:outside2:inside2*outside2:parent_inside2:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:inside2*parent_inside2:treelevelsim:treelevelsim*inside2:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos' \
	'nrleafsratio:maxinside:maxoutside:maxinside*maxoutside2:parent_maxinside:parent_catpos:catpos.parent_catpos:insideST2:insideTS2:maxinsideST:maxinsideTS:maxinside*parent_maxinside:treelevelsim:treelevelsim*maxinside:treespansim:treespansim*treelevelsim:giza:parent_giza:giza.catpos:moses:moses.catpos:sister_giza.catpos:sister_moses.catpos:moseslink:treespansim.catpos:treelevelsim.catpos:maxinside.catpos:children_giza.catpos:avgmaxinside:avgmaxoutside:avgmaxinside*avgmaxoutside:avgmaxinside.catpos'






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
		make FEAT=$$f EXTRAOPT='-S' sophie >> $@; \
	done
	echo "now with linked children & subtree nodes" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-C -S' sophie >> $@; \
	done

test_sophie_eco:
	for f in ${TESTFEAT}; do \
		make FEAT=$$f sophie_eco >> $@; \
	done
	echo "now with linked parents" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-P' sophie_eco >> $@; \
	done
	echo "now with linked children" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-C' sophie_eco >> $@; \
	done
	echo "now with linked subtree nodes" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-S' sophie_eco >> $@; \
	done
	echo "now with linked children & subtree nodes" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-C -S' sophie_eco >> $@; \
	done


test_eco_sophie:
	for f in ${TESTFEAT}; do \
		make FEAT=$$f eco_sophie >> $@; \
	done
	echo "now with linked parents" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-P' eco_sophie >> $@; \
	done
	echo "now with linked children" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-C' eco_sophie >> $@; \
	done
	echo "now with linked subtree nodes" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-S' eco_sophie >> $@; \
	done
	echo "now with linked children & subtree nodes" >> $@
	for f in ${TESTFEAT}; do \
		make FEAT=$$f EXTRAOPT='-C -S' eco_sophie >> $@; \
	done



test:
	for f in ${TESTFEAT}; do \
		make FEAT=$$f ${EXTRAOPT} sophie >> $@; \
	done

strategies:
	for s in ${STRATEGIES}; do \
		make SEARCH=$$s sophie >> $@; \
	done

single:
	for f in ${ALL_FEAT}; do \
		make FEAT=$$f sophie >> $@; \
	done


current+parent:
	for f in ${ALL_FEAT}; do \
		make FEAT="$$f:parent_$$f" sophie >> $@; \
	done






dublin: ${TRAIN}.dublin


${TRAIN}.dublin.gold: ${HOME}/projects/SMULTRON/Alignments_SMULTRON_Sophies_World_SV_EN.xml
	perl ../bin/sta2penn $< > $@

${TRAIN}.dublin: ${TRAIN}.dublin.gold
	paste -d "\n" ${TRAIN}.penn.src ${TRAIN}.penn.trg | \
	sed 'n;G;G;G' | \
	${HOME}/local64/bin/align moses/model/lex.0-0.f2e \
		moses/model/lex.0-0.e2f - 2> $@.log > $@



${TRAIN}.dublin2: ${TRAIN}.dublin.gold
	paste -d "\n" ${TRAIN}.penn.src ${TRAIN}.penn.trg | \
	sed 'n;G;G;G' | \
	${HOME}/local64/bin/align \
		ep+sw.lex.f2e ep+sw.lex.e2f - 2> $@.log > $@



