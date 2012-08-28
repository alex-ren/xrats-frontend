all: atscc-jailed

atscc-jailed: atscc-jailed.c
	gcc -g -o $@ $< -ljansson
	chmod u+s $@
