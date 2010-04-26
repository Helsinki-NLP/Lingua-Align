

run:
	rm -f wordalign.megam
	make wordalign.megam

FEAT=lcsr=3:word:suffix=3:moses:gizae2f:gizaf2e
# SEARCH=trg2src
SEARCH=munkres

NR_TRAIN=100
NR_DEV=47
NR_TEST=300

ALIGNTHR=0.15

wordalign.megam:
	../../bin/treealign \
		-c megam \
		-o '-maxi 50 -tune' \
		-a test.wa.nullalign -A wpt \
		-s test.e -S text \
		-t test.f -T text \
		-g moses/giza.e-f/A3.final.447.gz \
		-G moses/giza.f-e/A3.final.447.gz \
		-y moses/model/aligned.grow-diag-final.447 \
		-m $@ \
		-f ${FEAT} \
		-1 3 -2 1 -3 1 \
		-l ${SEARCH} \
		-n ${NR_TRAIN} \
		-V ${NR_DEV} \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-v  > test.align
	../../bin/eval_sta -g wpt test.wa.nullalign test.align


