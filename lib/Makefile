all: atscc-jailed

atscc-jailed: atscc-jailed.c
	gcc -m32 -g -o $@ $< -ljansson -lm
	chmod u+s $@
