

run:
	rm -f wordalign.megam
	make wordalign.megam

FEAT=lcsr=3:word:suffix=3

wordalign.megam:
	../../bin/treealign \
		-c megam \
		-a test.wa.nullalign -A wpt \
		-s test.e -S text \
		-t test.f -T text \
		-m $@ \
		-f ${FEAT} \
		-1 3 -2 1 -3 1 \
		-n 50 \
		-e 10 \
		-v  > test.align
	../../bin/eval_sta -g wpt test.wa.nullalign test.align


