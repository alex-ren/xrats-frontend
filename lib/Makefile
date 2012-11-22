all: atscc-jailed

atscc-jailed: atscc-jailed.c
	gcc -g -o $@ $< -Wl,-static -ljansson -Wl,-Bdynamic -lm
	chmod u+s $@
