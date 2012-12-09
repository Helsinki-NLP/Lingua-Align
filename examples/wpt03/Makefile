# simple example for how to use Lingua::Align 
# for discriminative word alignment
#
# make ................. run a little test using dice scores & LCSR
# make compare ......... visualize word alignment (mistakes)
#


run:
	rm -f wordalign.megam test.align
	make test.align


FEAT=lcsr=3:suffix=4:diceword=testword.cooc:dicesuffix=testsuffix.cooc:treelevelspan:moses:gizae2f:gizaf2e

# FEAT=lcsr=3:suffix=4:diceword=testword.cooc:dicesuffix=testsuffix.cooc:treelevelspan:neighbor11_diceword=testword.cooc:neighbor-1-1_diceword=testword.cooc

# FEAT=moses:gizae2f:gizaf2e


# SEARCH=trg2src
SEARCH=munkres

NR_TRAIN=100
NR_DEV=47
NR_TEST=300

ALIGNTHR=0.1

# -5 .... history features "linked neighbors" (specify distance patterns)
#
# EXTRAOPT=-5 -1:-1
# EXTRAOPT=-5 -1:-1+-2:-1+-2:-1
# EXTRAOPT=-5 -1:-1+-1:0+0:-1 -R 2

test.align: testword.cooc testsuffix.cooc
	../../bin/treealign \
		-c megam \
		-o '-maxi 50 -tune' \
		-a test.wa.nullalign -A wpt \
		-s test.e -S text \
		-t test.f -T text \
		-g moses/giza.e-f/A3.final.447.gz \
		-G moses/giza.f-e/A3.final.447.gz \
		-y moses/model/aligned.intersect.447 \
		-m wordalign.megam \
		-f ${FEAT} \
		-1 3 -2 1 -3 1 \
		-l ${SEARCH} \
		-n ${NR_TRAIN} \
		-V ${NR_DEV} \
		-e ${NR_TEST} \
		-x ${ALIGNTHR} \
		-v ${EXTRAOPT} > test.align
	../../bin/treealigneval -g wpt test.wa.nullalign test.align

#		-y moses/model/aligned.grow-diag-final.447 \

# print link matrices for comparing alignments with gold standard

compare: test.align
	../../bin/compare_wordalign -A corpus \
		-b wpt -B corpus -S test.e -T test.f \
		test.align test.wa.nullalign



testword.cooc:
	../../bin/coocfreq -s test.e -t test.f \
			-x word -y word \
			-f testword.src -e testword.trg -c $@

testsuffix.cooc:
	../../bin/coocfreq -s test.e -t test.f \
			-x suffix=4 -y suffix=4 \
			-f testsuffix.src -e testsuffix.trg -c $@


# better: count frequencies on the entire hansards corpus!

word.cooc:
	../../bin/coocfreq -s hansard.e -t hansard.f \
			-x word -y word \
			-f word.src -e word.trg -c $@

suffix.cooc:
	../../bin/coocfreq -s hansard.e -t hansard.f \
			-x suffix=4 -y suffix=4 \
			-f suffix.src -e suffix.trg -c $@

